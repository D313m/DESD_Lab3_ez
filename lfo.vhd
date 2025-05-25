library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    generic(
        CHANNEL_LENGHT  : integer := 24;  -- Width of the audio data
        JOYSTICK_LENGHT : integer := 10;  -- Width of the joystick Y-axis input
        CLK_PERIOD_NS   : integer := 10;  -- Clock period 
        TRIANGULAR_COUNTER_LENGHT : integer := 10  -- Bit width for triangular waveform counter
    );
    Port (
        aclk            : in std_logic;  -- System clock
        aresetn         : in std_logic;  -- Active-low reset

        lfo_period      : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0);  -- Joystick Y value to modulate frequency
        lfo_enable      : in std_logic;  -- Enable signal for LFO effect (SW0)

        s_axis_tvalid   : in std_logic;  -- AXI-Stream input valid
        s_axis_tdata    : in std_logic_vector(CHANNEL_LENGHT-1 downto 0);  -- AXI-Stream input audio data
        s_axis_tlast    : in std_logic;  -- AXI-Stream input last
        s_axis_tready   : out std_logic; -- AXI-Stream input ready

        m_axis_tvalid   : out std_logic; -- AXI-Stream output valid
        m_axis_tdata    : out std_logic_vector(CHANNEL_LENGHT-1 downto 0); -- AXI-Stream output audio data
        m_axis_tlast    : out std_logic; -- AXI-Stream output last
        m_axis_tready   : in std_logic   -- AXI-Stream output ready
    );
end entity;

architecture Behavioral of LFO is

    -- Max value for triangle wave counter
    constant COUNTER_MAX : integer := 2 ** TRIANGULAR_COUNTER_LENGHT - 1;

    -- Constants used for calculating LFO period
    constant LFO_COUNTER_BASE_PERIOD : integer := 80000;
    constant ADJUSTMENT_FACTOR       : integer := 75;

    -- Internal signals
    signal up_counting     : std_logic := '1';  -- Direction of triangle wave (up or down)
    signal triangle_counter : integer range 0 to COUNTER_MAX := 0;  -- Triangle wave counter

    signal lfo_timer       : integer := 0;  -- Timer to trigger triangle step
    signal lfo_period_int  : integer := 0;  -- LFO period value (calculated based on joystick input)

    signal gain            : unsigned(CHANNEL_LENGHT-1 downto 0);  -- Gain factor derived from triangle wave
    signal audio_in        : signed(CHANNEL_LENGHT-1 downto 0);    -- Signed input audio
    signal audio_out       : signed(CHANNEL_LENGHT-1 downto 0);    -- Signed output audio

begin

    -- Triangle wave generator (oscillator)
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                -- Reset all internal counters
                triangle_counter <= 0;
                up_counting <= '1';
                lfo_timer <= 0;
            else
                -- Calculate LFO period based on joystick input
                lfo_period_int <= LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR * to_integer(unsigned(lfo_period));

                -- Step the triangle counter periodically
                if lfo_timer >= lfo_period_int then
                    lfo_timer <= 0;

                    -- Count up or down based on direction
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
                    -- Wait until period is met
                    lfo_timer <= lfo_timer + 1;
                end if;
            end if;
        end if;
    end process;

    -- Connect AXI input ready to output ready
    s_axis_tready <= m_axis_tready;

    -- Audio processing and LFO gain modulation
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                -- Reset output control signals
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                m_axis_tlast  <= '0';
            else
                if s_axis_tvalid = '1' and m_axis_tready = '1' then
                    -- Convert incoming audio to signed
                    audio_in <= signed(s_axis_tdata);

                    if lfo_enable = '1' then
                        -- Apply gain from triangle wave
                        gain <= to_unsigned(triangle_counter, CHANNEL_LENGHT);
                        audio_out <= resize(audio_in * signed(gain), CHANNEL_LENGHT) / COUNTER_MAX;
                    else
                        -- Pass audio through unchanged
                        audio_out <= audio_in;
                    end if;

                    -- Send modulated or original audio to output
                    m_axis_tdata  <= std_logic_vector(audio_out);
                    m_axis_tvalid <= '1';
                    m_axis_tlast  <= s_axis_tlast;
                else
                    m_axis_tvalid <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture;
