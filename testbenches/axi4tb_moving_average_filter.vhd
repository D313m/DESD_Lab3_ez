-- L'ottimo e' il nemico del bene

-- The purpose of this testbench is to simulate the behavior of the moving_average_filter
-- module and verify the correctness of the AXI4 protocol implementation.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi4tb_moving_average_filter is
--  Port ( );
end axi4tb_moving_average_filter;

architecture Behavioral of axi4tb_moving_average_filter is
	-- DUT component declaration
	component moving_average_filter is
		generic (
			-- Filter order expressed as 2^(FILTER_ORDER_POWER)
			FILTER_ORDER_POWER : integer  := 5;
			TDATA_WIDTH        : positive := 24
		);
		port (
			aclk          : in  std_logic;
			aresetn       : in  std_logic;
	
			s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
			s_axis_tvalid : in  std_logic; 
			s_axis_tready : out std_logic; 
			s_axis_tlast  : in  std_logic;
			
			m_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
			m_axis_tvalid : out std_logic; 
			m_axis_tready : in  std_logic;
			m_axis_tlast  : out std_logic
			
		);
	end component;
	
	constant DATA_WIDTH : integer := 24;
	
	constant TCLK   : time := 10 ns;
	constant RSTWND : time := 3 * TCLK;
	
	constant DATA_GEN_LOOP   : integer := 7;
	constant INV_DATA_OFFSET : integer := 10;
	constant READY_GEN_LOOP  : integer := 2;


	-- Testbench signals
	signal clk           : std_logic := '1';
	signal aresetn       : std_logic;
	
	signal s_axis_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal s_axis_tvalid : std_logic;
	signal s_axis_tready : std_logic;
	signal s_axis_tlast  : std_logic;

	signal m_axis_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal m_axis_tvalid : std_logic;
	signal m_axis_tready : std_logic;
	signal m_axis_tlast  : std_logic;


	-- Procedure to generate a packet group
	procedure generate_packet_group(
		signal packet_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		signal packet_valid : out std_logic;
		signal packet_ready : in  std_logic;
		signal packet_last  : out std_logic
	) is
	begin
		for j in 0 to 1 loop
			-- Data packets
			for i in 0 to DATA_GEN_LOOP loop
			
				packet_data <= std_logic_vector(to_signed(i, DATA_WIDTH));
				packet_valid <= '1';
				wait for TCLK;
				if packet_ready /= '1' then
					wait until packet_ready = '1';
					wait for TCLK;
				end if;
				packet_valid <= '0';
				
				wait for TCLK * j;
				
				packet_data <= std_logic_vector(to_signed(-i, DATA_WIDTH));
				packet_valid <= '1';
				packet_last <= '1';
				wait for TCLK;
				if packet_ready /= '1' then
					wait until packet_ready = '1';
					wait for TCLK;
				end if;
				packet_valid <= '0';
				packet_last <= '0';
				
			end loop;
	
			-- Invalid packets
			for i in 2 * j downto 0 loop
				packet_data <= std_logic_vector(to_signed(INV_DATA_OFFSET + i, DATA_WIDTH));
				wait for TCLK * j;
			end loop;
			
		end loop;
	end procedure;

	-- Procedure to toggle m_axis_tready signal
	procedure toggle_m_axis_tready(
		signal m_axis_tready : out std_logic
	) is
	begin
		for j in READY_GEN_LOOP downto 0 loop
			for i in 0 to READY_GEN_LOOP + 1 loop
				m_axis_tready <= '1';
				wait for TCLK * (2 * j + 1);
				m_axis_tready <= '0';
				wait for TCLK * i;
			end loop;
		end loop;
	end procedure;

begin
	clk <= not clk after TCLK / 2;
	
	-- Instantiate the DUT
	DUT_inst : moving_average_filter
		generic map (
			TDATA_WIDTH => DATA_WIDTH
		)
		port map (
			s_axis_tdata  => s_axis_tdata,
			s_axis_tvalid => s_axis_tvalid,
			s_axis_tready => s_axis_tready,
			s_axis_tlast  => s_axis_tlast,

			m_axis_tdata  => m_axis_tdata,
			m_axis_tvalid => m_axis_tvalid,
			m_axis_tready => m_axis_tready,
			m_axis_tlast  => m_axis_tlast,
			
			aclk          => clk,
			aresetn       => aresetn
		);
	
	-- Testbench processes
	process
	begin
		m_axis_tready <= '0';
		wait for RSTWND;
		
		while true loop
			-- Toggle m_axis_tready signal
			toggle_m_axis_tready(m_axis_tready);
		end loop;
	end process;
	
	process
	begin
		-- Initialize signals
		aresetn       <= '0';
		s_axis_tvalid <= '0';
		s_axis_tlast  <= '0';

		wait for RSTWND;
		aresetn       <= '1';
		
		-- Generate packet groups
		for i in 0 to 3 loop
			generate_packet_group(
				packet_data  => s_axis_tdata,
				packet_valid => s_axis_tvalid,
				packet_ready => s_axis_tready,
				packet_last  => s_axis_tlast
			);
		end loop;
		
		wait;
	end process;
end Behavioral;