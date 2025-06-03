library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity balance_controller is
	generic (
		TDATA_WIDTH    : positive := 24;
		BALANCE_WIDTH  : positive := 10;
		BALANCE_STEP_2 : positive := 6 -- Balance values per step = 2**BALANCE_STEP_2
	);
	Port (
		aclk           : in  std_logic;
		aresetn        : in  std_logic;
		
		s_axis_tvalid  : in  std_logic;
		s_axis_tdata   : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);
		s_axis_tready  : out std_logic;
		s_axis_tlast   : in  std_logic;
		
		m_axis_tvalid  : out std_logic;
		m_axis_tdata   : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
		m_axis_tready  : in  std_logic;
		m_axis_tlast   : out std_logic;
		
		balance        : in  std_logic_vector(BALANCE_WIDTH - 1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is
	
	constant MAX_POS_STEP : integer := BALANCE_WIDTH - BALANCE_STEP_2 - 1; -- 2**MAX_POS_STEP = Max. value of the positive step number
	
	type BUFFER_t is record
		tdata  : std_logic_vector(TDATA_WIDTH - 1 downto 0);
		tlast  : std_logic;
	end record BUFFER_t;
	signal PL1 : BUFFER_t;
	signal PL2 : BUFFER_t;
	
	signal balance_sig : signed(BALANCE_WIDTH-1 downto 0); -- Already normalized
	signal step_number : integer range -2**MAX_POS_STEP to 2**MAX_POS_STEP;

begin

	process(aclk, aresetn)
		variable v_balance_sig : signed(BALANCE_WIDTH-1 downto 0);
	begin
		if aresetn = '0' then
		
			PL1 <= ((Others => '0'), '0');
			PL2 <= ((Others => '0'), '0');
			
			balance_sig <= (Others => '0');
			step_number <= 0;
			
		elsif rising_edge(aclk) then
			
			balance_sig <= signed(balance);
			
			-- Step computation that exploits the intrinsic rounding down (even for negative numbers) of the simple shift division
			-- Step  0: [-32, +31]. (-32 + 32) / 64 =  0 and  (31 + 32) / 64 =  0
			-- Step  1: [+32, +95].  (32 + 32) / 64 = +1 and  (95 + 32) / 64 =  +1
			-- Step -1: [-96, -33]. (-96 + 32) / 64 = -1 and (-33 + 32) / 64 =  -1
			step_number <= to_integer(shift_right(balance_sig + 2**(BALANCE_STEP_2 - 1), BALANCE_STEP_2)); 	
			
			if m_axis_tready = '1' and s_axis_tvalid = '1' then
				
				PL1.tdata <= s_axis_tdata;
				PL1.tlast <= s_axis_tlast;
				
				
				PL2 <= PL1;
				
				if step_number < 0 and PL1.tlast = '1' then
					PL2.tdata <= std_logic_vector(shift_right(signed(PL1.tdata), -step_number));
				elsif step_number >= 0 and PL1.tlast /= '1' then
					PL2.tdata <= std_logic_vector(shift_right(signed(PL1.tdata), step_number));
				end if;
				
				
				m_axis_tdata <= PL2.tdata;
				m_axis_tlast <= PL2.tlast;
				
			end if;
			
		end if;
	end process;
	
	m_axis_tvalid <= s_axis_tvalid;
	s_axis_tready <= m_axis_tready;
	
end Behavioral;
