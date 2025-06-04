library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter_en is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER : integer  := 5;
		TDATA_WIDTH        : positive := 24
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
		
		enable_filter : in  std_logic
	);
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is
	
	subtype SUM_BUFFER_t is signed(s_axis_tdata'HIGH + FILTER_ORDER_POWER downto 0); -- Sum of current data_buffer contents.
	signal filter_sum_L : SUM_BUFFER_t;                                              -- It is updated by calculating the difference of the oldest datum in
	signal filter_sum_R : SUM_BUFFER_t;                                              -- the buffer with the new one instead of computing the whole sum every time.
	
	signal pointer_L : unsigned(FILTER_ORDER_POWER - 1 downto 0);
	signal pointer_R : unsigned(FILTER_ORDER_POWER - 1 downto 0);
	
	type DATA_BUFFER_t is array (2**FILTER_ORDER_POWER - 1 downto 0) of signed(s_axis_tdata'RANGE);
	signal data_buffer_L : DATA_BUFFER_t;
	signal data_buffer_R : DATA_BUFFER_t;
	
	signal s_axis_tdata_sig  : signed(s_axis_tdata'RANGE);
	signal s_axis_tdata_sig2 : signed(s_axis_tdata'RANGE);
	
	signal filter_diff : signed(s_axis_tdata'LENGTH downto 0); -- 1 more bit needed to store the result.
	
	type BUFFER_t is record
		tvalid : std_logic; -- Indicates whether the datum of the corresponding pipeline stage is valid.
		tlast  : std_logic;
	end record BUFFER_t;
	
	signal PL1 : BUFFER_t;
	signal PL2 : BUFFER_t;
	signal PL3 : BUFFER_t;
	
	signal s_axis_tready_sig : std_logic;
	
	signal enable_filter_sig : std_logic;
	
begin
	process(aclk, aresetn)
	
		variable filter_sum_v  : SUM_BUFFER_t;
		
		variable PL1_ready : boolean;
		variable PL2_ready : boolean;
		variable PL3_ready : boolean;
		
	begin
		if aresetn = '0' then
			
			data_buffer_L <= (Others => (Others => '0'));
			data_buffer_R <= (Others => (Others => '0'));
			filter_sum_L  <= (Others => '0');
			filter_sum_R  <= (Others => '0');
			
			s_axis_tready_sig <= '0';
			enable_filter_sig <= '0';
			s_axis_tdata_sig  <= (Others => '0');
			s_axis_tdata_sig2 <= (Others => '0');
			m_axis_tdata      <= (Others => '0');
			
			PL1 <= (Others => '0');
			PL2 <= (Others => '0');
			PL3 <= (Others => '0');
			
			pointer_L <= (Others => '0');
			pointer_R <= (Others => '0');
			
		elsif rising_edge(aclk) then
			
			PL3_ready := PL3.tvalid /= '1' or m_axis_tready = '1';
			PL2_ready := PL2.tvalid /= '1' or PL3_ready;
			PL1_ready := PL1.tvalid /= '1' or PL2_ready;
			
			if PL3_ready then -- Master handshake or invalid
				
				PL3.tvalid <= '0';
				
			end if;
			
			if PL3_ready and PL2.tvalid = '1' then
				
				PL2.tvalid <= '0';
				PL3 <= PL2;
				
				if PL2.tlast = '1' then -- R
					
					filter_sum_v  := filter_sum_R + resize(filter_diff, filter_sum_v'LENGTH) ;
					filter_sum_R <= filter_sum_v;
					
				else -- L
					
					filter_sum_v  := filter_sum_L + resize(filter_diff, filter_sum_v'LENGTH) ;
					filter_sum_L <= filter_sum_v;
					
				end if;
				
				if enable_filter_sig = '1' then
					m_axis_tdata <= std_logic_vector(filter_sum_v(filter_sum_v'HIGH downto filter_sum_v'HIGH - (m_axis_tdata'LENGTH - 1))); -- Rounded down (even negatives)
				else -- All-pass: Data is not modified
					m_axis_tdata <= std_logic_vector(s_axis_tdata_sig2);
				end if;

			end if;
			
			if PL2_ready and PL1.tvalid = '1' then
			
				PL1.tvalid <= '0';
				PL2 <= PL1;
				
				s_axis_tdata_sig2 <= s_axis_tdata_sig;
				
				if PL1.tlast = '1' then -- R
					
					filter_diff <= resize(s_axis_tdata_sig, TDATA_WIDTH + 1) - resize(data_buffer_R(to_integer(pointer_R)), TDATA_WIDTH + 1);
					
					data_buffer_R(to_integer(pointer_R)) <= s_axis_tdata_sig;
					
					pointer_R <= pointer_R + 1;
					
				else -- L
					
					filter_diff <= resize(s_axis_tdata_sig, TDATA_WIDTH + 1) - resize(data_buffer_L(to_integer(pointer_L)), TDATA_WIDTH + 1);
					
					data_buffer_L(to_integer(pointer_L)) <= s_axis_tdata_sig;
					
					pointer_L <= pointer_L + 1;
					
				end if;
				
			end if;
			
			if s_axis_tready_sig = '1' and s_axis_tvalid  = '1' then -- Slave handshake
			                                                         -- This pipeline stage (the first) was introduced just to reduce the 
			                                                         -- criticality of the master (prev. module) -> slave (this module)
			                                                         -- tdata connection by removing the diff computation from it.
				s_axis_tdata_sig <= signed(s_axis_tdata);
				PL1.tlast <= s_axis_tlast;
				PL1.tvalid <= '1';
				PL1_ready := (PL1.tvalid /= '1' and PL2.tvalid /= '1') or
				             (PL1.tvalid /= '1' and PL3_ready) or
				             (PL2.tvalid /= '1' and PL3_ready);
				-- After this slave handshake, the module will be ready next cycle if there were at least two empty (invalid) stages or
				-- one empty stage and the master handshake happened (freeing up an extra stage).
			end if;
			
			if PL1_ready then
			
				s_axis_tready_sig <= '1';
				
			else
			
				s_axis_tready_sig <= '0';
				
			end if;
			
			enable_filter_sig <= enable_filter;
			
		end if;
	end process;
	
	s_axis_tready <= s_axis_tready_sig;
	m_axis_tvalid <= PL3.tvalid;
	m_axis_tlast  <= PL3.tlast;
	
end Behavioral;