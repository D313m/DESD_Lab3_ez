-- L'ottimo e' il nemico del bene

-- The purpose of this testbench is to simulate the behavior of the digilent_jstk2
-- module and verify the correctness of the AXI4 protocol implementation.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi4tb_digilent_jstk2 is
--  Port ( );
end axi4tb_digilent_jstk2;

architecture Behavioral of axi4tb_digilent_jstk2 is
	-- DUT component declaration
	component digilent_jstk2 is
		generic (
			DELAY_US      : integer := 25;           -- Interpacket delay [us]
			CLKFREQ       : integer := 100_000_000;  -- Frequency of the aclk signal [Hz]
			SPI_SCLKFREQ  : integer := 50_000        -- Frequency of the SPI SCLK clock signal [Hz]
		);
		Port ( 
			aclk          : in  std_logic;
			aresetn       : in  std_logic;
			
			-- Data going to the SPI IP-Core
			m_axis_tvalid : out std_logic;
			m_axis_tdata  : out std_logic_vector(7 downto 0);
			m_axis_tready : in  std_logic;
			
			-- Data coming from the SPI IP-Core
			s_axis_tvalid : in  std_logic;
			s_axis_tdata  : in  std_logic_vector(7 downto 0);
			
			-- Joystick and button values read from the module
			jstk_x        : out std_logic_vector(9 downto 0);
			jstk_y        : out std_logic_vector(9 downto 0);
			btn_jstk      : out std_logic;
			btn_trigger   : out std_logic;
			
			-- LED RGB values to send to the module
			led_r         : in  std_logic_vector(7 downto 0);
			led_g         : in  std_logic_vector(7 downto 0);
			led_b         : in  std_logic_vector(7 downto 0)
		);
	end component;
	
	constant R_VAL : std_logic_vector(7 downto 0) := x"AA";
	constant G_VAL : std_logic_vector(7 downto 0) := x"BB";
	constant B_VAL : std_logic_vector(7 downto 0) := x"CC";
	
	constant X_VAL : integer := 300;
	constant Y_VAL : integer := 500;
	
	constant DATA_STRUCT_BYTES : integer := 5; -- Match with DUT's constant!
	
	constant DATA_WIDTH : integer := 8;
	
	constant TCLK   : time := 10 ns;
	constant RSTWND : time := 3 * TCLK;
	
	constant DATA_GEN_LOOP   : integer := 6;
	constant INV_DATA_OFFSET : integer := 10;
	constant READY_GEN_LOOP  : integer := 2;
	constant ENABLE_GEN_LOOP : integer := 5;

	-- Testbench signals
	signal clk           : std_logic := '1';
	signal aresetn       : std_logic;
	
	signal s_axis_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal s_axis_tvalid : std_logic;

	signal m_axis_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal m_axis_tvalid : std_logic;
	signal m_axis_tready : std_logic;
	
	signal jstk_x        : std_logic_vector(9 downto 0);
	signal jstk_y        : std_logic_vector(9 downto 0);
	signal btn_jstk      : std_logic;
	signal btn_trigger   : std_logic;
	
	signal led_r         : std_logic_vector(7 downto 0) := R_VAL;
	signal led_g         : std_logic_vector(7 downto 0) := G_VAL;
	signal led_b         : std_logic_vector(7 downto 0) := B_VAL;


	-- Procedure to generate a packet group
	procedure generate_packet_group(
		signal packet_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		signal packet_valid : out std_logic;
		signal packet_start : in  std_logic
	) is
		variable ADC_out    : std_logic_vector(2 * DATA_WIDTH - 1 downto 0);
	begin
		for j in 0 to 1 loop
				
			-- Data packets
			for i in 0 to DATA_GEN_LOOP loop
			
				wait for TCLK;
				if packet_start /= '1' then
					wait until packet_start = '1';
					wait for TCLK;
				end if;
				
				
				ADC_out := std_logic_vector(to_unsigned(X_VAL + i, DATA_WIDTH * 2));
				packet_data <= ADC_out(DATA_WIDTH - 1 downto 0);
				packet_valid <= '1';
				wait for TCLK;
				packet_valid <= '0';
				
				wait for TCLK * j;
				
				packet_data <= ADC_out(2 * DATA_WIDTH - 1 downto DATA_WIDTH);
				packet_valid <= '1';
				wait for TCLK;
				packet_valid <= '0';
				
				wait for TCLK * j;
				
				
				ADC_out := std_logic_vector(to_unsigned(Y_VAL + i, DATA_WIDTH * 2));
				packet_data <= ADC_out(DATA_WIDTH - 1 downto 0);
				packet_valid <= '1';
				wait for TCLK;
				packet_valid <= '0';
				
				wait for TCLK * j;
				
				packet_data <= ADC_out(2 * DATA_WIDTH - 1 downto DATA_WIDTH);
				packet_valid <= '1';
				wait for TCLK;
				packet_valid <= '0';
				
				wait for TCLK * j;
				
				
				packet_data <= "000000" & std_logic_vector(to_unsigned(i mod 2, 1)) & std_logic_vector(to_unsigned((2 * i + 3) mod 2, 1));
				packet_valid <= '1';
				wait for TCLK;
				packet_valid <= '0';
				
				wait for TCLK * j;
				
				if DATA_STRUCT_BYTES > 5 then
					for k in 6 to DATA_STRUCT_BYTES loop
						
						packet_data <= x"10";
						packet_valid <= '1';
						wait for TCLK;
						packet_valid <= '0';
						
						wait for TCLK * j;
						
					end loop;
				end if;
				
				wait for TCLK * DATA_STRUCT_BYTES;
				
			end loop;
	
			-- Invalid packets
			for i in 2 * j downto 0 loop
				packet_data <= std_logic_vector(to_signed(INV_DATA_OFFSET + i, DATA_WIDTH));
				wait for TCLK * j;
			end loop;
			
		end loop;
	end procedure;

	-- Procedure to toggle m_axis_tready signal
	procedure toggle_std_logic(
		signal sig : out std_logic;
		gen_loop   : in  integer
	) is
	begin
		for j in gen_loop downto 0 loop
			for i in 0 to gen_loop + 1 loop
				sig <= '1';
				wait for TCLK * (2 * j + 1);
				sig <= '0';
				wait for TCLK * i;
			end loop;
		end loop;
	end procedure;

begin
	clk <= not clk after TCLK / 2;
	
	-- Instantiate the DUT
	DUT_inst : digilent_jstk2
		generic map (
			DELAY_US => 1,
			CLKFREQ  => ((1 us) / TCLK) * 1e9
		)
		port map (
			s_axis_tdata  => s_axis_tdata,
			s_axis_tvalid => s_axis_tvalid,

			m_axis_tdata  => m_axis_tdata,
			m_axis_tvalid => m_axis_tvalid,
			m_axis_tready => m_axis_tready,
			
			aclk          => clk,
			aresetn       => aresetn,
			
			jstk_x        => jstk_x,
			jstk_y        => jstk_y,
			btn_jstk      => btn_jstk,
			btn_trigger   => btn_trigger,
			
			led_r         => led_r,
			led_g         => led_g,
			led_b         => led_b
		);
	
	-- Testbench processes
	process
	begin
		m_axis_tready <= '0';
		wait for RSTWND;
		
		while true loop
			-- Toggle m_axis_tready signal
			toggle_std_logic(
				sig => m_axis_tready,
				gen_loop => READY_GEN_LOOP
			);
		end loop;
	end process;
	
	process
	begin
		-- Initialize signals
		aresetn       <= '0';
		s_axis_tvalid <= '0';

		wait for RSTWND;
		aresetn       <= '1';
		
		-- Generate packet groups
		for i in 0 to 3 loop
			generate_packet_group(
				packet_data  => s_axis_tdata,
				packet_valid => s_axis_tvalid,
				packet_start => m_axis_tvalid
			);
		end loop;
		
		wait;
	end process;
end Behavioral;