library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

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
	component moving_average_filter is
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
			m_axis_tready : in  std_logic
		);
	end component moving_average_filter;
	
	component all_pass_filter is
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
	end component all_pass_filter;
	
	signal enable_filter_sig : std_logic;
	
	signal s_axis_tready_tvalid : std_logic;
	signal m_axis_tready_tvalid : std_logic;
	
	signal ma_s_axis_tready : std_logic;
	signal ma_m_axis_tvalid : std_logic;
	signal ma_m_axis_tdata  : std_logic_vector(TDATA_WIDTH - 1 downto 0);
	signal ma_m_axis_tlast  : std_logic;
	
	signal ap_s_axis_tready : std_logic;
	signal ap_m_axis_tvalid : std_logic;
	signal ap_m_axis_tdata  : std_logic_vector(TDATA_WIDTH - 1 downto 0);
	signal ap_m_axis_tlast  : std_logic;
	
begin
	
	moving_average_filter_inst : moving_average_filter
	generic map (
		FILTER_ORDER_POWER => FILTER_ORDER_POWER,
		TDATA_WIDTH        => TDATA_WIDTH
	)
	port map (
		aclk          => aclk,
		aresetn       => aresetn,
		
		s_axis_tvalid => s_axis_tready_tvalid,
		s_axis_tdata  => s_axis_tdata,
		s_axis_tlast  => s_axis_tlast,
		s_axis_tready => ma_s_axis_tready,
		
		m_axis_tvalid => ma_m_axis_tvalid,
		m_axis_tdata  => ma_m_axis_tdata,
		m_axis_tlast  => ma_m_axis_tlast,
		m_axis_tready => m_axis_tready
	);
	
	all_pass_filter_inst : all_pass_filter
	generic map (
		TDATA_WIDTH   => TDATA_WIDTH
	)
	port map (
		aclk          => aclk,
		aresetn       => aresetn,
		
		s_axis_tvalid => s_axis_tready_tvalid,
		s_axis_tdata  => s_axis_tdata,
		s_axis_tlast  => s_axis_tlast,
		s_axis_tready => ap_s_axis_tready,
		
		m_axis_tvalid => ap_m_axis_tvalid,
		m_axis_tdata  => ap_m_axis_tdata,
		m_axis_tlast  => ap_m_axis_tlast,
		m_axis_tready => m_axis_tready
	);
	
	process(aclk, aresetn)
	begin
		if aresetn = '0' then
			
			enable_filter_sig <= '0';
			
		elsif rising_edge(aclk) then
			
			if m_axis_tready_tvalid = '1' then -- Master handshake
				enable_filter_sig <= enable_filter;
			end if;
			
		end if;
	end process;
	
	s_axis_tready_tvalid <= '1' when ma_s_axis_tready = '1' and ap_s_axis_tready = '1' and s_axis_tvalid = '1' else '0';
	m_axis_tready_tvalid <= '1' when ma_m_axis_tvalid = '1' and ap_m_axis_tvalid = '1' and m_axis_tready = '1' else '0';
	
	m_axis_tdata <= ma_m_axis_tdata when enable_filter_sig = '1' else ap_m_axis_tdata;
	m_axis_tlast <= ma_m_axis_tlast when enable_filter_sig = '1' else ap_m_axis_tlast;
	
	s_axis_tready <= s_axis_tready_tvalid;
	m_axis_tvalid <= m_axis_tready_tvalid;
	
end Behavioral;