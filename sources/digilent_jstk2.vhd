library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digilent_jstk2 is
	generic (
		DELAY_US      : integer := 500;           -- Interpacket delay [us]
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
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is
	
	constant CMDSETLEDRGB : std_logic_vector(7 downto 0) := x"84"; -- SetLEDRGB command, as per the JSTK2 datasheet.
	constant DUMMYVAL     : std_logic_vector(7 downto 0) := x"FF"; -- Value to use for PARAM4. Not reserved for commands.
	
	type SEND_STATE_t is (IDLE, SEND);
	signal tx_state : SEND_STATE_t;
	
	type RECEIVE_STATE_t is (INVALID, VALID);
	signal rx_state : RECEIVE_STATE_t;
	
	constant STD_DATA_STRUCT_BYTES : integer := 5;
	
	type DATA_BUFFER_t is array (integer range <>) of std_logic_vector(m_axis_tdata'RANGE);
	signal tx_buffer : DATA_BUFFER_t(0 to STD_DATA_STRUCT_BYTES - 3);
	signal rx_buffer : DATA_BUFFER_t(0 to STD_DATA_STRUCT_BYTES - 2);
	
	signal tx_index  : integer range 0 to STD_DATA_STRUCT_BYTES - 1;
	signal rx_index  : integer range 0 to STD_DATA_STRUCT_BYTES - 1;

	constant DELAY_CNT_MAX : integer := CLKFREQ/ 1_000_000 * DELAY_US;
	signal delay_cnt : integer range 0 to DELAY_CNT_MAX - 1;
	--- probe code
	component ila_0 is port (
	   clk: in std_logic;
	   probe0: in std_logic_vector(9 downto 0);
	   probe1: in std_logic_vector(9 downto 0);
	   probe2: in std_logic_vector(1 downto 0);
	   probe3: in std_logic_vector(7 downto 0)
	);
	end component;
	signal btns: std_logic_vector(1 downto 0);
	signal btn_jstk_int  : std_logic;
	signal btn_trigger_int : std_logic;
	signal rx_probe :  std_logic_vector(7 downto 0);
		signal copy_jstk_x        :  std_logic_vector(9 downto 0);
		signal copy_jstk_y        :  std_logic_vector(9 downto 0);
	
begin
 ila_inst : ila_0
    port map (
        clk => aclk,
        probe0 => copy_jstk_x,
        probe1 => copy_jstk_y,
        probe2 => btns,
        probe3 => rx_probe
 );

	process(aclk)
	begin
		if aresetn = '0' then
			
			tx_state <= IDLE;
			rx_state <= INVALID;
			delay_cnt     <= 0;
			
			m_axis_tvalid <= '0';
			m_axis_tdata  <= (Others => '0');
			
			btn_jstk      <= '0';
			btn_trigger   <= '0';
			jstk_x        <= (Others => '0');
			jstk_y        <= (Others => '0');
			
		elsif rising_edge(aclk) then
		
			RX_MNGT : if rx_state = VALID and s_axis_tvalid = '1' then
				
				if rx_index = STD_DATA_STRUCT_BYTES - 1 then -- fsButtons byte. Outputs can be updated.
				
				    rx_probe <= s_axis_tdata;
					btn_jstk_int  <= s_axis_tdata(0);
					btn_trigger_int  <= s_axis_tdata(1);
					btns <= btn_jstk_int & btn_trigger_int;
					btn_jstk    <= s_axis_tdata(0);
					btn_trigger <= s_axis_tdata(1);
					
					jstk_x <= rx_buffer(1)(1 downto 0) & rx_buffer(0); -- [High byte; Low Byte], Right justified.
					jstk_y <= rx_buffer(3)(1 downto 0) & rx_buffer(2); -- [High byte; Low Byte], Right justified.
					
					copy_jstk_x <= rx_buffer(1)(1 downto 0) & rx_buffer(0);
					copy_jstk_y <= rx_buffer(3)(1 downto 0) & rx_buffer(2);
					rx_state <= INVALID;
					                                                  
				else -- X and Y position bytes
					
					rx_index <= rx_index + 1;
					rx_buffer(rx_index) <= s_axis_tdata;
					
				end if;
				
			end if RX_MNGT;
		
			TX_MNGT : case tx_state is
				
				when IDLE => -- Wait for interpacket delay
					m_axis_tvalid <= '0';
					if delay_cnt = DELAY_CNT_MAX - 1 then
						
						delay_cnt <= 0;
						
						tx_buffer(0) <= led_r;
						tx_buffer(1) <= led_g;
						tx_buffer(2) <= led_b;
						
						m_axis_tdata <= CMDSETLEDRGB;
						m_axis_tvalid <= '1';
						
						tx_index <= 0;
						tx_state <= SEND;
						
						rx_index <= 0;
						rx_state <= VALID;
						
					else
						
						delay_cnt <= delay_cnt + 1;
						
					end if;
				
				when SEND =>
				    m_axis_tvalid <= '1';  -- Always valid while in SEND

    case tx_index is
        when 0 | 1 | 2 =>
            m_axis_tdata <= tx_buffer(tx_index);
        when 3 =>
            m_axis_tdata <= DUMMYVAL;
        when 4 =>
            m_axis_tdata <= (others => '0');
    end case;

    if m_axis_tready = '1' then
        if tx_index = STD_DATA_STRUCT_BYTES - 1 then
            m_axis_tvalid <= '0';  -- Stop after final byte accepted
            tx_state <= IDLE;
        else
            tx_index <= tx_index + 1;
        end if;
    end if;
					
			end case TX_MNGT;
			
		end if;
	end process;
	
end Behavioral;
