-- Typo in generics' names (LENGHT). The entity interface was left as provided.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFO is
	generic(
		CHANNEL_LENGHT            : integer := 24;  -- Audio signal bit width
		JOYSTICK_LENGHT           : integer := 10;  -- Joystick_y input bit width
		CLK_PERIOD_NS             : integer := 10;  -- Clock period [ns]
		TRIANGULAR_COUNTER_LENGHT : integer := 10   -- Triangular wave period bit width
	);
	Port (
		aclk          : in  std_logic;
		aresetn       : in  std_logic;
		lfo_period    : in  std_logic_vector(JOYSTICK_LENGHT - 1 downto 0); -- Joystick Y input. Offset already applied.
		lfo_enable    : in  std_logic;
		
		s_axis_tvalid : in  std_logic;
		s_axis_tdata  : in  std_logic_vector(CHANNEL_LENGHT - 1 downto 0);
		s_axis_tlast  : in  std_logic;
		s_axis_tready : out std_logic;
		
		m_axis_tvalid : out std_logic;
		m_axis_tdata  : out std_logic_vector(CHANNEL_LENGHT - 1 downto 0);
		m_axis_tlast  : out std_logic;
		m_axis_tready : in  std_logic
	);
end entity;

architecture Behavioral of LFO is
	
	-- LFO counter (clock cycles for a step)
	constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000;                                             -- Base period of the LFO counter [us]
	constant LFO_COUNTER_BASE_PERIOD    : integer := LFO_COUNTER_BASE_PERIOD_US * 1e3 / CLK_PERIOD_NS; -- Base period of the LFO counter [clock cycles]
	constant ADJUSTMENT_FACTOR          : integer := 90; -- Multiplicative factor to scale the joystick y position input into a delta of the LFO counter 
	                                                     -- period [clock cycles]. NOTE: Frequency dependent! (as instructed)
	
	signal lfo_counter                  : integer range 0 to LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR * (-(2**(JOYSTICK_LENGHT - 1)));
	signal lfo_period_int               : integer range LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR * (2**(JOYSTICK_LENGHT - 1) - 1) to 
	                                                    LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR * (-(2**(JOYSTICK_LENGHT - 1)));
	signal lfo_period_delta_adjusted    : integer range ADJUSTMENT_FACTOR * (-(2**(JOYSTICK_LENGHT - 1))) to ADJUSTMENT_FACTOR * (2**(JOYSTICK_LENGHT - 1) - 1);
	signal lfo_period_delta             : signed(lfo_period'RANGE);  -- Yet to be scaled by ADJUSTMENT_FACTOR
	
	
	-- Triangle counter (steps in triangle wave)
	constant HALF_COUNTER_LENGTH : integer := TRIANGULAR_COUNTER_LENGHT - 1; -- 1 bit less, as the triangle_counter only covers semi-periods of the triangle wave
	constant COUNTER_MAX         : integer := 2**HALF_COUNTER_LENGTH - 1;
	constant COUNTER_MIN         : integer := 0;
	
	signal up_counting           : std_logic; -- Indicates the direction of the triangle_counter
	signal triangle_counter      : unsigned(HALF_COUNTER_LENGTH - 1 downto 0); 
	
	
	-- Pipeline to perform the product of two arbitrary values (s_axis_tdata and triangle_counter)
	type PIPELINE_STAGE_t is record 
		partial_sum        : signed(CHANNEL_LENGHT + HALF_COUNTER_LENGTH - 1 downto 0);
		tdata              : signed(s_axis_tdata'RANGE);
		triangle_counter_p : unsigned(triangle_counter'RANGE);
		tlast              : std_logic;
	end record;
	type PIPELINE_t is array(integer range <>) of PIPELINE_STAGE_t;
	signal pipeline : PIPELINE_t(0 to HALF_COUNTER_LENGTH - 1);
	
begin
	
	LFO_PERIOD_CALC : process(aclk, aresetn)
	begin
		if aresetn = '0' then
			
			lfo_period_int   <= LFO_COUNTER_BASE_PERIOD;
			lfo_period_delta <= (Others => '0');
			
		elsif rising_edge(aclk) then
			
			lfo_period_int            <= LFO_COUNTER_BASE_PERIOD - lfo_period_delta_adjusted;
			lfo_period_delta          <= signed(lfo_period);
			lfo_period_delta_adjusted <= ADJUSTMENT_FACTOR * to_integer(lfo_period_delta);
			
		end if;
	end process LFO_PERIOD_CALC;
	
	
	COUNTERS : process(aclk, aresetn)
	begin
		if aresetn = '0' then
			
			triangle_counter <= (Others => '0');
			up_counting      <= '1';
			lfo_counter      <= 0;
			
		elsif rising_edge(aclk) then
			
			if lfo_counter >= lfo_period_int then -- >= To avoid problems with LFO period reduction
				
				lfo_counter <= 0;
				
				if up_counting = '1' then
					
					triangle_counter <= triangle_counter + 1;
					if triangle_counter = COUNTER_MAX - 1 then
						up_counting <= '0';
					end if;
					
				else
					
					triangle_counter <= triangle_counter - 1;
					if triangle_counter = COUNTER_MIN + 1 then
						up_counting <= '1';
					end if;
					
				end if;
				
			else
				
				lfo_counter <= lfo_counter + 1;
				
			end if;
			
		end if;
	end process COUNTERS;
	
	-- Given that triangle_counter is defined in the following manner: unsigned(LENGTH - 1 downto 0)
	-- triangle_counter = SUMMATION in i from triangle_counter'LOW to triangle_counter'HIGH of triangle_counter(i) * 2**i 
	-- s_axis_tdata * triangle_counter = SUMMATION in i from triangle_counter'LOW to triangle_counter'HIGH of s_axis_tdata * triangle_counter(i) * 2**i 
	PRODUCT_CALC : process(aclk, aresetn)
		variable shifted_tdata : signed(CHANNEL_LENGHT + HALF_COUNTER_LENGTH - 1 downto 0);
	begin
		if aresetn = '0' then
			
			pipeline <= (Others => (
				partial_sum        => (Others => '0'),
				tdata              => (Others => '0'),
				triangle_counter_p => (Others => '0'),
				tlast              => '0'
			));
			
		elsif rising_edge(aclk) then
			
			if m_axis_tready = '1' and s_axis_tvalid = '1' then
				
				pipeline(0).tdata               <= signed(s_axis_tdata);
				pipeline(0).triangle_counter_p  <= triangle_counter;
				pipeline(0).tlast               <= s_axis_tlast;
				
				if triangle_counter(0) = '1' then
					pipeline(0).partial_sum     <= resize(signed(s_axis_tdata), CHANNEL_LENGHT + HALF_COUNTER_LENGTH);
				else
					pipeline(0).partial_sum     <= (Others => '0');
				end if;
				
				
				for i in 1 to pipeline'HIGH loop
					
					pipeline(i)                 <= pipeline(i - 1);
					
					if pipeline(i).triangle_counter_p(i) = '1' then -- If the i-th bit of triangle_counter_p is high, the summation contains tdata * 2**i
						shifted_tdata := shift_left(resize(pipeline(i).tdata, CHANNEL_LENGHT + HALF_COUNTER_LENGTH), i);
						pipeline(i).partial_sum <= pipeline(i - 1).partial_sum + shifted_tdata;
					end if;
					
				end loop;
			
			end if;
			
		end if;
	end process PRODUCT_CALC;
	
	
	s_axis_tready <= m_axis_tready;
	m_axis_tvalid <= s_axis_tvalid;
	
	m_axis_tdata <= std_logic_vector(pipeline(pipeline'HIGH).partial_sum(CHANNEL_LENGHT + HALF_COUNTER_LENGTH - 1 downto HALF_COUNTER_LENGTH))
	                when lfo_enable = '1' else std_logic_vector(pipeline(pipeline'HIGH).tdata);
	m_axis_tlast <= pipeline(pipeline'HIGH).tlast;
	
end architecture;