library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFO is
	generic(
		CHANNEL_LENGHT  : integer := 24;  -- Bit width of audio signal
		JOYSTICK_LENGHT : integer := 10;  -- Bit width of joystick_y input
		CLK_PERIOD_NS   : integer := 10;  -- Clock period in nanoseconds 
		TRIANGULAR_COUNTER_LENGHT : integer := 10  -- Triangular wave period bit length
	);
	Port (
		aclk			: in std_logic;  -- Clock signal
		aresetn		 : in std_logic;  -- Asynchronous reset (active low)
		lfo_period	  : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0); -- Joystick Y input
		lfo_enable	  : in std_logic;  -- LFO activation switch (SW0)

		-- AXI4-Stream input interface
		s_axis_tvalid   : in std_logic;
		s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready   : out std_logic;

		-- AXI4-Stream output interface
		m_axis_tvalid   : out std_logic;
		m_axis_tdata	: out std_logic_vector(CHANNEL_LENGHT-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready   : in std_logic
	);
end entity;

architecture Behavioral of LFO is

	constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000; -- Base period of the LFO counter in us (when the joystick is at the center)
	constant ADJUSTMENT_FACTOR : integer := 90; -- Multiplicative factor to scale the LFO period properly with the joystick y position
	constant LFO_COUNTER_BASE_PERIOD : integer := LFO_COUNTER_BASE_PERIOD_US * 1e3 / CLK_PERIOD_NS;
	constant COUNTER_MAX			  : integer := 2**(TRIANGULAR_COUNTER_LENGHT - 1) - 1;
	
	signal up_counting      : std_logic := '1';  -- Direction of triangle waveform
	signal triangle_counter : unsigned(TRIANGULAR_COUNTER_LENGHT - 2 downto 0); -- 1 bit less
	signal lfo_timer        : integer;  -- Timer for triangle step control
	signal lfo_period_int   : integer;
	signal lfo_period_sig : signed(lfo_period'RANGE);
	
	type PIPELINE_STAGE_t is record 
		partial_sum : signed(CHANNEL_LENGHT + (TRIANGULAR_COUNTER_LENGHT - 1) - 1 downto 0);
		tdata : signed(s_axis_tdata'RANGE);
		triangle_counter_p : unsigned(triangle_counter'RANGE);
		tlast : std_logic;
	end record;
	type PIPELINE_t is array(integer range <>) of PIPELINE_STAGE_t;
	signal pipeline : PIPELINE_t(0 to (TRIANGULAR_COUNTER_LENGHT - 1) - 1);
	
begin

	-- Process to calculate LFO period dynamically from joystick_y input
	process(aclk, aresetn)
	begin
		if aresetn = '0' then
			lfo_period_int <= LFO_COUNTER_BASE_PERIOD;
		elsif rising_edge(aclk) then
		    lfo_period_sig <= signed(lfo_period);
			lfo_period_int <= LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR * to_integer(lfo_period_sig);
		end if;
	end process;

	-- Process to generate triangle waveform
	process(aclk, aresetn)
	begin
		if aresetn = '0' then
			
			triangle_counter <= (others => '0');
			up_counting <= '1';
			lfo_timer <= 0;
			
		elsif rising_edge(aclk) then

			if lfo_timer >= lfo_period_int then
				lfo_timer <= 0;
				
				if up_counting = '1' then
					
					triangle_counter <= triangle_counter + 1;
					if triangle_counter = COUNTER_MAX - 1 then
						up_counting <= '0';
					end if;
					
				else
					
					triangle_counter <= triangle_counter - 1;
					if triangle_counter = 1 then
						up_counting <= '1';
					end if;
					
				end if;
			else
				
				lfo_timer <= lfo_timer + 1;
				
			end if;
		end if;
	end process;
	
	process(aclk, aresetn)
		variable tmp : signed(CHANNEL_LENGHT + (TRIANGULAR_COUNTER_LENGHT - 1) - 1 downto 0); 
	begin
		if aresetn = '0' then
			
			pipeline <= (Others => (
				(Others => '0'),
				(Others => '0'),
				(Others => '0'),
				'0'
			));
			
		elsif rising_edge(aclk) then
			if m_axis_tready = '1' and s_axis_tvalid = '1' then
			
				if triangle_counter(0) = '1' then
					pipeline(0).partial_sum <= resize(signed(s_axis_tdata), CHANNEL_LENGHT + (TRIANGULAR_COUNTER_LENGHT - 1));
				else
					pipeline(0).partial_sum <= (Others => '0');
				end if;
				
				pipeline(0).tdata <= signed(s_axis_tdata);
				pipeline(0).triangle_counter_p <= triangle_counter;
				pipeline(0).tlast <= s_axis_tlast;
				
				for i in 1 to pipeline'HIGH loop
					
					pipeline(i) <= pipeline(i - 1);
					if pipeline(i).triangle_counter_p(i) = '1' then
						pipeline(i).partial_sum <= pipeline(i - 1).partial_sum + shift_left(resize(pipeline(i).tdata, CHANNEL_LENGHT + (TRIANGULAR_COUNTER_LENGHT - 1)), i);
					end if;
					
				end loop;
			
			end if;
		end if;
	end process;
	
	s_axis_tready <= m_axis_tready;
	m_axis_tvalid <= s_axis_tvalid;
	
	m_axis_tdata <= std_logic_vector(pipeline(pipeline'HIGH).partial_sum(CHANNEL_LENGHT + (TRIANGULAR_COUNTER_LENGHT - 1) - 1 
	                                                                                downto TRIANGULAR_COUNTER_LENGHT - 1)) when lfo_enable = '1' else std_logic_vector(pipeline(pipeline'HIGH).tdata);
	m_axis_tlast <= pipeline(pipeline'HIGH).tlast;
	
end architecture;
