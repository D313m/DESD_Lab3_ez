library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- LFO: Low Frequency Oscillator module for audio amplitude modulation
-- Applies triangle-based amplitude control to incoming audio via AXI4-Stream
entity LFO is
    generic(
        CHANNEL_LENGHT  : integer := 24;  -- Bit width of audio signal
        JOYSTICK_LENGHT : integer := 10;  -- Bit width of joystick_y input
        CLK_PERIOD_NS   : integer := 10;  -- Clock period in nanoseconds 
        TRIANGULAR_COUNTER_LENGHT : integer := 10  -- Bit width for triangle counter
    );
    Port (
        aclk            : in std_logic;  -- Clock signal
        aresetn         : in std_logic;  -- Asynchronous reset (active low)
        lfo_period      : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0); -- Joystick Y input
        lfo_enable      : in std_logic;  -- LFO activation switch (SW0)

        -- AXI4-Stream input interface
        s_axis_tvalid   : in std_logic;
        s_axis_tdata    : in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready   : out std_logic;

        -- AXI4-Stream output interface
        m_axis_tvalid   : out std_logic;
        m_axis_tdata    : out std_logic_vector(CHANNEL_LENGHT-1 downto 0);
        m_axis_tlast    : out std_logic;
        m_axis_tready   : in std_logic
    );
end entity;

architecture Behavioral of LFO is

    -- Constants for triangle counter and period modulation
    constant COUNTER_MAX              : integer := 2 ** TRIANGULAR_COUNTER_LENGHT - 1;
    constant LFO_COUNTER_BASE_PERIOD : integer := 80000;
    constant ADJUSTMENT_FACTOR        : integer := 75;
    constant MIN_LFO_PERIOD           : integer := 200;

    -- Triangle waveform generation signals
    signal up_counting      : std_logic := '1';  -- Direction of triangle waveform
    signal triangle_counter : unsigned(TRIANGULAR_COUNTER_LENGHT-1 downto 0) := (others => '0');
    signal lfo_timer        : integer := 0;  -- Timer for triangle step control
    signal lfo_period_int   : integer := 0;  -- Actual LFO period

    -- Audio and modulation signals
    signal audio_in         : signed(CHANNEL_LENGHT-1 downto 0) := (others => '0');
    signal audio_out        : signed(CHANNEL_LENGHT-1 downto 0) := (others => '0');
    signal gain_ext         : unsigned(47 downto 0);  -- Extended triangle value for scaling
    signal scaled_sample    : signed(95 downto 0);    -- Product of audio × gain
begin

    -- Process to calculate LFO period dynamically from joystick_y input
    process(aclk)
        variable temp : integer;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                lfo_period_int <= LFO_COUNTER_BASE_PERIOD;
            else
                temp := LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR * to_integer(unsigned(lfo_period));
                if temp < MIN_LFO_PERIOD then
                    lfo_period_int <= MIN_LFO_PERIOD;
                else
                    lfo_period_int <= temp;
                end if;
            end if;
        end if;
    end process;

    -- Process to generate triangle waveform
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                triangle_counter <= (others => '0');
                up_counting <= '1';
                lfo_timer <= 0;
            else
                if lfo_timer >= lfo_period_int then
                    lfo_timer <= 0;
                    -- Increment or decrement triangle counter based on direction
                    if up_counting = '1' then
                        if triangle_counter = COUNTER_MAX then
                            up_counting <= '0';
                            triangle_counter <= triangle_counter - 1;
                        else
                            triangle_counter <= triangle_counter + 1;
                        end if;
                    else
                        if triangle_counter = 0 then
                            up_counting <= '1';
                            triangle_counter <= triangle_counter + 1;
                        else
                            triangle_counter <= triangle_counter - 1;
                        end if;
                    end if;
                else
                    -- Wait until period is reached
                    lfo_timer <= lfo_timer + 1;
                end if;
            end if;
        end if;
    end process;

    -- AXI4-Stream audio processing and modulation output
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                m_axis_tlast  <= '0';
            elsif s_axis_tvalid = '1' and m_axis_tready = '1' then
                -- Capture input audio
                audio_in <= signed(s_axis_tdata);

                if lfo_enable = '1' then
                    -- Extend triangle counter value to match audio width and calculate scaled output
                    gain_ext <= resize(triangle_counter, 48);
                    scaled_sample <= resize(audio_in, 48) * signed(gain_ext);
                    audio_out <= resize(scaled_sample srl 10, CHANNEL_LENGHT);  -- Shift instead of divide
                else
                    -- Bypass LFO modulation
                    audio_out <= audio_in;
                end if;

                -- Write output data to AXI stream
                m_axis_tdata  <= std_logic_vector(audio_out);
                m_axis_tvalid <= '1';
                m_axis_tlast  <= s_axis_tlast;
            else
                m_axis_tvalid <= '0';
            end if;
        end if;
    end process;

    -- Pass-through AXI ready signal
    s_axis_tready <= m_axis_tready;

end architecture;
