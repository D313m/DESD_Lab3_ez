library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digilent_jstk2 is
  generic (
    DELAY_US        : integer := 25;             -- Delay between transactions (us)
    CLKFREQ         : integer := 100_000_000;    -- System clock frequency (Hz)
    SPI_SCLKFREQ    : integer := 66_666          -- SPI clock (Hz) 
  );
  port (
    aclk            : in  std_logic;
    aresetn         : in  std_logic;

    -- SPI Master (AXI4-Stream) Output
    m_axis_tvalid   : out std_logic;
    m_axis_tdata    : out std_logic_vector(7 downto 0);
    m_axis_tready   : in  std_logic;

    -- SPI Master (AXI4-Stream) Input
    s_axis_tvalid   : in  std_logic;
    s_axis_tdata    : in  std_logic_vector(7 downto 0);

    -- Joystick outputs
    jstk_x          : out std_logic_vector(9 downto 0);
    jstk_y          : out std_logic_vector(9 downto 0);
    btn_jstk        : out std_logic;
    btn_trigger     : out std_logic;

    -- LED RGB inputs
    led_r           : in std_logic_vector(7 downto 0);
    led_g           : in std_logic_vector(7 downto 0);
    led_b           : in std_logic_vector(7 downto 0)
  );
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is
  type state_type is (IDLE, SEND, WAIT_RESP, DONE, DELAY);
  signal state       : state_type := IDLE;

  signal tx_buffer   : std_logic_vector(31 downto 0);
  signal rx_buffer   : std_logic_vector(31 downto 0);
  signal tx_index    : integer range 0 to 3 := 0;
  signal rx_index    : integer range 0 to 3 := 0;

  signal delay_cnt   : integer range 0 to (CLKFREQ / 1_000_000 * DELAY_US) := 0;

begin
  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        -- Reset
        state <= IDLE;
        tx_index <= 0;
        rx_index <= 0;
        delay_cnt <= 0;
        m_axis_tvalid <= '0';
        m_axis_tdata  <= (others => '0');
        jstk_x <= (others => '0');
        jstk_y <= (others => '0');
        btn_jstk <= '0';
        btn_trigger <= '0';
        rx_buffer <= (others => '0');

      else
        case state is

          when IDLE =>
            tx_buffer <= x"84" & led_r & led_g & led_b;
            tx_index <= 0;
            rx_index <= 0;
            m_axis_tdata <= tx_buffer(31 downto 24);
            m_axis_tvalid <= '1';
            state <= SEND;

          when SEND =>
            if m_axis_tready = '1' then
              if tx_index = 3 then
                m_axis_tvalid <= '0';
                state <= WAIT_RESP;
              else
                tx_index <= tx_index + 1;
                m_axis_tdata <= tx_buffer(31 - (tx_index + 1)*8 downto 24 - (tx_index + 1)*8);
              end if;
            end if;

          when WAIT_RESP =>
            if s_axis_tvalid = '1' then
              rx_buffer(31 - rx_index*8 downto 24 - rx_index*8) <= s_axis_tdata;
              if rx_index = 3 then
                state <= DONE;
              else
                rx_index <= rx_index + 1;
              end if;
            end if;

          when DONE =>
            -- Joystick X: byte0 (8 bit) + bit15:14
            -- Joystick Y: byte2 (8 bit) + bit13:12
            jstk_x <= rx_buffer(31 downto 24) & rx_buffer(15 downto 14);
            jstk_y <= rx_buffer(23 downto 16) & rx_buffer(13 downto 12);
            btn_trigger <= rx_buffer(9);
            btn_jstk    <= rx_buffer(8);

            delay_cnt <= 0;
            state <= DELAY;

          when DELAY =>
            if delay_cnt < (CLKFREQ / 1_000_000 * DELAY_US) then
              delay_cnt <= delay_cnt + 1;
            else
              delay_cnt <= 0;
              state <= IDLE;
            end if;

          when others =>
            state <= IDLE;

        end case;
      end if;
    end if;
  end process;
end Behavioral;
