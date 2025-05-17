library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity all_pass_filter is
	generic (
		TDATA_WIDTH   : positive := 24
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
		m_axis_tready : in  std_logic
	);
end all_pass_filter;

architecture Behavioral of all_pass_filter is

	signal s_axis_tready_sig : std_logic;
	signal m_axis_tvalid_sig : std_logic;
	
begin
	process(aclk, aresetn)
	begin
		if aresetn = '0' then
			
			s_axis_tready_sig <= '0';
			m_axis_tvalid_sig <= '0';
			m_axis_tlast      <= '0';
			m_axis_tdata      <= (Others => '0');
			
		elsif rising_edge(aclk) then
		
			if m_axis_tvalid_sig = '1' and m_axis_tready = '1' then -- Master handshake
				
				m_axis_tvalid_sig <= '0';
				s_axis_tready_sig <= '1';
				m_axis_tlast      <= '0';
				
			end if;
			
			if s_axis_tready_sig = '1' and s_axis_tvalid = '1' then -- Slave handshake
				
				m_axis_tdata <= s_axis_tdata;
				m_axis_tlast <= s_axis_tlast;
				m_axis_tvalid_sig <= '1';
				s_axis_tready_sig <= '0';
				
			end if;
			
			if m_axis_tvalid_sig /= '1' and s_axis_tready_sig /= '1' then
				
				s_axis_tready_sig <= '1';
				
			end if;
			
		end if;
	end process;
	
	s_axis_tready <= s_axis_tready_sig;
	m_axis_tvalid <= m_axis_tvalid_sig;
	
end Behavioral;