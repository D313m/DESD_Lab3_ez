library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digilent_jstk2 is
    generic (
        DELAY_US        : integer := 25;
        CLKFREQ         : integer := 100_000_000;
        SPI_SCLKFREQ    : integer := 66_666
    );
    Port ( 
        aclk            : in  STD_LOGIC;
        aresetn         : in  STD_LOGIC;

        -- SPI Master OUT
        m_axis_tvalid   : out STD_LOGIC;
        m_axis_tdata    : out STD_LOGIC_VECTOR(7 downto 0);
        m_axis_tready   : in  STD_LOGIC;

        -- SPI Master IN
        s_axis_tvalid   : in STD_LOGIC;
        s_axis_tdata    : in STD_LOGIC_VECTOR(7 downto 0);

        -- Output joystick values
        jstk_x          : out std_logic_vector(9 downto 0);
        jstk_y          : out std_logic_vector(9 downto 0);
        btn_jstk        : out std_logic;
        btn_trigger     : out std_logic;

        -- Input LED color
        led_r           : in std_logic_vector(7 downto 0);
        led_g           : in std_logic_vector(7 downto 0);
        led_b           : in std_logic_vector(7 downto 0)
    );
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is

    -- FSM state encoding
    constant STATE_IDLE : integer := 0;
    constant STATE_LOAD : integer := 1;
    constant STATE_SEND : integer := 2;
    constant STATE_DONE : integer := 3;

    signal state      : integer range 0 to 3 := STATE_IDLE;

    signal tx_buffer  : std_logic_vector(31 downto 0); -- 4 bytes to send
    signal tx_index   : integer range 0 to 3 := 0;

    signal rx_buffer  : std_logic_vector(31 downto 0); -- 4 bytes received
    signal rx_index   : integer range 0 to 3 := 0;

    signal delay_cnt  : integer range 0 to CLKFREQ / 1_000_000 * DELAY_US := 0;

begin

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= STATE_IDLE;
                m_axis_tvalid <= '0';
                tx_index <= 0;
                rx_index <= 0;
                delay_cnt <= 0;
            else
                case state is

                    when STATE_IDLE =>
                        -- Prepare LED command packet
                        tx_buffer(31 downto 24) <= x"84";    -- CMDSETLEDRGB
                        tx_buffer(23 downto 16) <= led_r;
                        tx_buffer(15 downto 8)  <= led_g;
                        tx_buffer(7 downto 0)   <= led_b;
                        tx_index <= 0;
                        rx_index <= 0;
                        state <= STATE_LOAD;

                    when STATE_LOAD =>
                        if m_axis_tready = '1' then
                            m_axis_tvalid <= '1';
                            m_axis_tdata <= tx_buffer(31 downto 24);
                            state <= STATE_SEND;
                        end if;

                    when STATE_SEND =>
                        if m_axis_tready = '1' then
                            -- Receive data in parallel
                            if s_axis_tvalid = '1' then
                                rx_buffer(31 - rx_index*8 downto 24 - rx_index*8) <= s_axis_tdata;
                                rx_index <= rx_index + 1;
                            end if;

                    -- tx was here                            

                            if tx_index = 2 then
                                m_axis_tvalid <= '0';
                                state <= STATE_DONE;
                                delay_cnt <= 0;
                            else
                                m_axis_tdata <= tx_buffer(31 - (tx_index+1)*8 downto 24 - (tx_index+1)*8);
                            end if;
                            tx_index <= tx_index + 1;
                        end if;

                    when STATE_DONE =>
                        -- Extract joystick and button data from received bytes
                        jstk_x <= rx_buffer(23 downto 16) & rx_buffer(9 downto 8);  -- X: Byte1 + 2 LSB
                        jstk_y <= rx_buffer(15 downto 8) & rx_buffer(7 downto 6);   -- Y: Byte2 + 2 LSB
                        btn_trigger <= rx_buffer(5);
                        btn_jstk    <= rx_buffer(4);
                        if delay_cnt < CLKFREQ / 1_000_000 * DELAY_US then
                            delay_cnt <= delay_cnt + 1;
                        else
                            state <= STATE_IDLE;
                        end if;

                    when others =>
                        state <= STATE_IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
