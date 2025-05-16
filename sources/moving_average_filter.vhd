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
	subtype SUM_BUFFER_t is signed(s_axis_tdata'HIGH + FILTER_ORDER_POWER downto 0);
	signal filter_sum_L : SUM_BUFFER_t;
	signal filter_sum_R : SUM_BUFFER_t;
	
	type DATA_BUFFER_t is array (2**FILTER_ORDER_POWER - 1 downto 1) of signed(s_axis_tdata'RANGE); -- N-1 registers per channel needed in the shift register
	signal data_buffer_L : DATA_BUFFER_t;
	signal data_buffer_R : DATA_BUFFER_t;
	
	signal s_axis_tready_sig : std_logic;
	signal m_axis_tvalid_sig : std_logic;
	signal s_axis_tdata_sig  : signed(s_axis_tdata'RANGE);
	
begin
	process(aclk, aresetn)
		variable filter_diff_v : signed(s_axis_tdata'LENGTH downto 0); -- 1 more bit
		variable filter_sum_v  : SUM_BUFFER_t;
	begin
		if aresetn = '0' then
			
			data_buffer_L <= (Others => (Others => '0'));
			data_buffer_R <= (Others => (Others => '0'));
			filter_sum_L  <= (Others => '0');
			filter_sum_R  <= (Others => '0');
			
			s_axis_tready_sig <= '0';
			m_axis_tvalid_sig <= '0';
			m_axis_tdata <= (Others => '0');
			m_axis_tlast <= '0';
			
		elsif rising_edge(aclk) then
			
			SLAVE_HANDSHAKE : if s_axis_tready_sig = '1' and s_axis_tvalid  = '1' then
				
				if s_axis_tlast = '1' then -- R
				
					filter_diff_v := (s_axis_tdata_sig(s_axis_tdata_sig'HIGH) & s_axis_tdata_sig) - 
									 (data_buffer_R(1)(s_axis_tdata'HIGH) & data_buffer_R(1));
					filter_sum_v  := filter_sum_R + resize(filter_diff_v, filter_sum_v'LENGTH) ;
					filter_sum_R <= filter_sum_v;
					
					data_buffer_R(2**FILTER_ORDER_POWER - 2 downto 1) <= data_buffer_R(2**FILTER_ORDER_POWER - 1 downto 2);
					data_buffer_R(2**FILTER_ORDER_POWER - 1) <= s_axis_tdata_sig;
					
				else -- L
					
					filter_diff_v := (s_axis_tdata_sig(s_axis_tdata_sig'HIGH) & s_axis_tdata_sig) - 
									 (data_buffer_L(1)(s_axis_tdata'HIGH) & data_buffer_L(1));
					filter_sum_v  := filter_sum_L + resize(filter_diff_v, filter_sum_v'LENGTH) ;
					filter_sum_L <= filter_sum_v;
					
					data_buffer_L(2**FILTER_ORDER_POWER - 2 downto 1) <= data_buffer_L(2**FILTER_ORDER_POWER - 1 downto 2);
					data_buffer_L(2**FILTER_ORDER_POWER - 1) <= s_axis_tdata_sig;
					
				end if;
				
				m_axis_tdata <= std_logic_vector(filter_sum_v(filter_sum_v'HIGH downto filter_sum_v'HIGH - (m_axis_tdata'LENGTH - 1)));
				m_axis_tlast <= s_axis_tlast;
				m_axis_tvalid_sig <= '1';
				
				s_axis_tready_sig <= '0';
				
			end if SLAVE_HANDSHAKE;
			
			
			MASTER_HANDSHAKE : if m_axis_tready = '1' and m_axis_tvalid_sig = '1' then
				s_axis_tready_sig <= '1';
				m_axis_tvalid_sig <= '0';
			end if MASTER_HANDSHAKE;
			
			
			INITIAL_READY : if s_axis_tready_sig /= '1' and m_axis_tvalid_sig /= '1' then
				s_axis_tready_sig <= '1';
			end if INITIAL_READY;
			
		end if;
	end process;
	
	m_axis_tvalid <= m_axis_tvalid_sig;
	s_axis_tready <= s_axis_tready_sig;
	s_axis_tdata_sig <= signed(s_axis_tdata);
	
end Behavioral;