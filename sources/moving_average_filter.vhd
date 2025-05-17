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
	
	--type STATUS_t is (READY, VALID, INIT);
	--signal status : STATUS_t;
	
	signal s_axis_tlast_sig  : std_logic;
	signal s_axis_tlast_sig2 : std_logic;
	signal s_axis_tdata_sig  : signed(s_axis_tdata'RANGE);
	
	signal filter_diff : signed(s_axis_tdata'LENGTH downto 0); -- 1 more bit
	
begin
	process(aclk, aresetn)
		variable filter_sum_v  : SUM_BUFFER_t;
	begin
		if aresetn = '0' then
			
			data_buffer_L <= (Others => (Others => '0'));
			data_buffer_R <= (Others => (Others => '0'));
			filter_sum_L  <= (Others => '0');
			filter_sum_R  <= (Others => '0');
			
			--status <= INIT;
			
			m_axis_tdata <= (Others => '0');
			m_axis_tlast <= '0';
			
			s_axis_tlast_sig  <= '0';
			s_axis_tlast_sig2 <= '0';
			s_axis_tdata_sig  <= (Others => '0');
			
		elsif rising_edge(aclk) then
			
			PIPELINE : if m_axis_tready = '1' and s_axis_tvalid = '1' then
			
			--if status = READY and s_axis_tvalid  = '1' then
			
				s_axis_tdata_sig <= signed(s_axis_tdata);
				s_axis_tlast_sig <= s_axis_tlast;
				--status <= ...
				
			--end if;
			
			--if then
				
				if s_axis_tlast_sig = '1' then -- R
				
					filter_diff <= (s_axis_tdata_sig(s_axis_tdata_sig'HIGH) & s_axis_tdata_sig) - 
									 (data_buffer_R(1)(s_axis_tdata'HIGH) & data_buffer_R(1));
					
					data_buffer_R(2**FILTER_ORDER_POWER - 2 downto 1) <= data_buffer_R(2**FILTER_ORDER_POWER - 1 downto 2);
					data_buffer_R(2**FILTER_ORDER_POWER - 1) <= s_axis_tdata_sig;
					
				else -- L
					
					filter_diff <= (s_axis_tdata_sig(s_axis_tdata_sig'HIGH) & s_axis_tdata_sig) - 
									 (data_buffer_L(1)(s_axis_tdata'HIGH) & data_buffer_L(1));
					
					data_buffer_L(2**FILTER_ORDER_POWER - 2 downto 1) <= data_buffer_L(2**FILTER_ORDER_POWER - 1 downto 2);
					data_buffer_L(2**FILTER_ORDER_POWER - 1) <= s_axis_tdata_sig;
					
				end if;
				
				s_axis_tlast_sig2 <= s_axis_tlast_sig;
				--status <= BUSY;
				
			--end if;
			
			--if status = BUSY then
			
				if s_axis_tlast_sig2 = '1' then -- R
					
					filter_sum_v  := filter_sum_R + resize(filter_diff, filter_sum_v'LENGTH) ;
					filter_sum_R <= filter_sum_v;
					
				else -- L
					
					filter_sum_v  := filter_sum_L + resize(filter_diff, filter_sum_v'LENGTH) ;
					filter_sum_L <= filter_sum_v;
					
				end if;
				
				m_axis_tdata <= std_logic_vector(filter_sum_v(filter_sum_v'HIGH downto filter_sum_v'HIGH - (m_axis_tdata'LENGTH - 1)));
				m_axis_tlast <= s_axis_tlast_sig2;
				--status <= VALID;
				
			--end if;
			
			--if (status = VALID and m_axis_tready = '1') or 
			--                      (status = INIT) then
			--	status <= READY;
			--end if;
			
			end if PIPELINE;
			
		end if;
	end process;
	
	--m_axis_tvalid <= '1' when status = VALID else '0';
	--s_axis_tready <= '1' when status = READY else '0';
	s_axis_tready <= m_axis_tready;
	m_axis_tvalid <= '0' when aresetn = '0' else '1';
	
end Behavioral;