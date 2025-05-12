library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER : integer := 5;
		TDATA_WIDTH        : positive := 24
	);
	Port (
		aclk          : in  std_logic;
		aresetn       : in  std_logic;

		s_axis_tvalid : in  std_logic;
		s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast  : in  std_logic;
		s_axis_tready : out std_logic;

		m_axis_tvalid : out std_logic;
		m_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast  : out std_logic;
		m_axis_tready : in  std_logic
	);
end moving_average_filter;

architecture Behavioral of moving_average_filter is
	type FILTER_DATA_BUFFER_t is array (0 to 2**FILTER_ORDER_POWER - 1) of std_logic_vector(s_axis_tdata'RANGE);
	type STEREO_FILTER_DATA_BUFFER_t is array (0 to 1) of FILTER_DATA_BUFFER_t;
	signal filter_data : STEREO_FILTER_DATA_BUFFER_t;
	
	signal s_axis_tready_sig : std_logic;
	signal m_axis_tvalid_sig : std_logic;
	signal counter : unsigned(FILTER_ORDER_POWER - 1 downto 0);
	
	procedure AVG_COMPUTATION (
		signal data : in  FILTER_DATA_BUFFER_t;
		signal avg  : out std_logic_vector(s_axis_tdata'RANGE)
	) is
		variable sum : signed(s_axis_tdata'HIGH + FILTER_ORDER_POWER downto 0);
	begin
		sum := (Others => '0');
		for i in counter'RANGE loop
			sum := sum + resize(signed(data(i)), sum'LENGTH);
		end loop;
		avg <= std_logic_vector(sum(sum'HIGH downto sum'HIGH - (s_axis_tdata'LENGTH - 1)));
	end procedure;
	
begin
	process(aclk, aresetn)
		variable tlast_select : integer range 0 to 1;
	begin
		if aresetn = '0' then
			
			filter_data <= (Others => (Others => (Others => '0')));
			s_axis_tready_sig <= '0';
			m_axis_tvalid_sig <= '0';
			
		elsif rising_edge(aclk) then
			
			SLAVE_HANDSHAKE : if s_axis_tready_sig = '1' and s_axis_tvalid  = '1' then
				
				if s_axis_tlast = '1' then
					tlast_select := 1;
				else
					tlast_select := 0;
				end if;
				
				filter_data(tlast_select)(to_integer(counter)) <= s_axis_tdata;
				
				AVG_COMPUTATION(
					data => filter_data(tlast_select),
					avg => m_axis_tdata
				);
				
				counter <= counter + tlast_select;
				
				m_axis_tlast <= s_axis_tlast;
				m_axis_tvalid_sig <= '1';
				
				s_axis_tready_sig <= '0';
				
			end if SLAVE_HANDSHAKE;
			
			
			MASTER_HANDSHAKE : if m_axis_tready = '1' and m_axis_tvalid_sig = '1' then
				s_axis_tready_sig <= '1';
				m_axis_tvalid_sig <= '0';
			end if MASTER_HANDSHAKE;
			
			
			INITIAL_VALID : if s_axis_tready_sig /= '1' and m_axis_tvalid_sig /= '1' then
				s_axis_tready_sig <= '1';
			end if INITIAL_VALID;
			
		end if;
	end process;
	
	m_axis_tvalid <= m_axis_tvalid_sig;
	s_axis_tready <= s_axis_tready_sig;
	
end Behavioral;