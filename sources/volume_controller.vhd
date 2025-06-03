library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
	Generic (
		TDATA_WIDTH   : positive := 24;
		VOLUME_WIDTH  : positive := 10;
		VOLUME_STEP_2 : positive := 6;         -- Volume values per step = 2**VOLUME_STEP_2
		HIGHER_BOUND  : integer :=  2**23 - 1; -- Inclusive
		LOWER_BOUND   : integer := -2**23      -- Inclusive
	);
	Port (
		aclk          : in  std_logic;
		aresetn       : in  std_logic;
		
		s_axis_tvalid : in  std_logic;
		s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);
		s_axis_tlast  : in  std_logic;
		s_axis_tready : out std_logic;
		
		m_axis_tvalid : out std_logic;
		m_axis_tdata  : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
		m_axis_tlast  : out std_logic;
		m_axis_tready : in  std_logic;
		
		volume        : in  std_logic_vector(VOLUME_WIDTH - 1 downto 0)
	);
end volume_controller;

architecture Behavioral of volume_controller is
	
	constant MAX_POS_STEP : integer := VOLUME_WIDTH - VOLUME_STEP_2 - 1; -- 2**MAX_POS_STEP = Max. value of the positive step number
	
	signal PL1_tdata : signed(TDATA_WIDTH - 1 downto 0);
	signal PL1_tlast : std_logic;
	signal PL2_tdata : signed(TDATA_WIDTH + MAX_POS_STEP - 1 downto 0); -- To account for left shift
	signal PL2_tlast : std_logic;
	signal PL3_tdata : signed(TDATA_WIDTH - 1 downto 0);
	signal PL3_tlast : std_logic;
	
	signal volume_sig  : signed(VOLUME_WIDTH-1 downto 0); -- Already normalized
	signal step_number : integer range -2**MAX_POS_STEP to 2**MAX_POS_STEP;

begin

	process(aclk, aresetn)
		variable v_volume_sig : signed(VOLUME_WIDTH-1 downto 0);
	begin
		if aresetn = '0' then
		
			PL1_tdata <= (Others => '0');
			PL1_tlast <= '0';
			PL2_tdata <= (Others => '0');
			PL2_tlast <= '0';
			PL3_tdata <= (Others => '0');
			PL3_tlast <= '0';
			
			volume_sig  <= (Others => '0');
			step_number <= 0;
			
		elsif rising_edge(aclk) then
			
			volume_sig <= signed(volume);
			
			-- Step computation that exploits the intrinsic rounding down (even for negative numbers) of the simple shift division
			-- Step  0: [-32, +31]. (-32 + 32) / 64 =  0 and  (31 + 32) / 64 =  0
			-- Step  1: [+32, +95].  (32 + 32) / 64 = +1 and  (95 + 32) / 64 =  +1
			-- Step -1: [-96, -33]. (-96 + 32) / 64 = -1 and (-33 + 32) / 64 =  -1
			step_number <= to_integer(shift_right(volume_sig + 2**(VOLUME_STEP_2 - 1), VOLUME_STEP_2)); 	
			
			if m_axis_tready = '1' and s_axis_tvalid = '1' then
				
				PL1_tdata <= signed(s_axis_tdata);
				PL1_tlast <= s_axis_tlast;
				
				
				PL2_tlast <= PL1_tlast;
				
				if step_number < 0 then
					PL2_tdata <= shift_right(resize(PL1_tdata, PL2_tdata'LENGTH), -step_number);
				else
					PL2_tdata <= shift_left(resize(PL1_tdata, PL2_tdata'LENGTH), step_number);
				end if;
				
				
				PL3_tlast <= PL2_tlast;
				
				if PL2_tdata > HIGHER_BOUND then
					PL3_tdata <= to_signed(HIGHER_BOUND, PL3_tdata'LENGTH);
				elsif PL2_tdata < LOWER_BOUND then
					PL3_tdata <= to_signed(LOWER_BOUND, PL3_tdata'LENGTH);
				else
					PL3_tdata <= PL2_tdata(PL3_tdata'RANGE);
				end if;
				
				
				m_axis_tdata <= std_logic_vector(PL3_tdata);
				m_axis_tlast <= PL3_tlast;
				
			end if;
			
		end if;
	end process;
	
	m_axis_tvalid <= s_axis_tvalid;
	s_axis_tready <= m_axis_tready;
	
end Behavioral;
