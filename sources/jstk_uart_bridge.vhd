library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity jstk_uart_bridge is
	generic (
		HEADER_CODE		: std_logic_vector(7 downto 0) := x"c0";
		TX_DELAY		: positive := 1_000_000;
		JSTK_BITS		: integer range 1 to 7 := 7
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);
		s_axis_tready	: out STD_LOGIC;

		jstk_x			: in std_logic_vector(9 downto 0);
		jstk_y			: in std_logic_vector(9 downto 0);
		btn_jstk		: in std_logic;
		btn_trigger		: in std_logic;

		led_r			: out std_logic_vector(7 downto 0);
		led_g			: out std_logic_vector(7 downto 0);
		led_b			: out std_logic_vector(7 downto 0)
	);
end jstk_uart_bridge;

architecture Behavioral of jstk_uart_bridge is

	type tx_state_type is (DELAY, SEND_HEADER, SEND_JSTK_X, SEND_JSTK_Y, SEND_BUTTONS);
	signal tx_state			: tx_state_type;

	signal tx_delay_counter	: integer range 0 to TX_DELAY-1;
	signal jstk_x_msb		: std_logic_vector(m_axis_tdata'range);
	signal jstk_y_msb		: std_logic_vector(m_axis_tdata'range);
	signal buttons			: std_logic_vector(m_axis_tdata'range);

	--------------------------------------------

	type rx_state_type is (IDLE, GET_HEADER, GET_LED_R, GET_LED_G, GET_LED_B);
	signal rx_state			: rx_state_type;

	signal led_r_temp		: std_logic_vector(led_r'range);
	signal led_g_temp		: std_logic_vector(led_r'range);

begin

	-- JSTK -> UART: Joystick position and buttons

	with tx_state select m_axis_tvalid <=
		'0'	when DELAY,
		'1'	when SEND_HEADER,
		'1'	when SEND_JSTK_X,
		'1'	when SEND_JSTK_Y,
		'1'	when SEND_BUTTONS;

	with tx_state select m_axis_tdata <=
		(others => '-')	when DELAY,
		HEADER_CODE		when SEND_HEADER,
		jstk_x_msb		when SEND_JSTK_X,
		jstk_y_msb		when SEND_JSTK_Y,
		buttons			when SEND_BUTTONS;

	jstk_x_msb	<= (jstk_x_msb'high downto JSTK_BITS => '0') & jstk_x(jstk_x'high downto jstk_x'high-JSTK_BITS+1);
	jstk_y_msb	<= (jstk_y_msb'high downto JSTK_BITS => '0') & jstk_y(jstk_y'high downto jstk_y'high-JSTK_BITS+1);
	buttons		<= (buttons'high downto 2 => '0') & btn_trigger & btn_jstk;

	process (aclk)
	begin
		if rising_edge(aclk) then
			if aresetn = '0' then
				
				tx_state			<= DELAY;
				tx_delay_counter	<= 0;

			else
				
				case tx_state is
					when DELAY =>
						if tx_delay_counter = TX_DELAY-1 then
							tx_delay_counter	<= 0;
							tx_state			<= SEND_HEADER;
						else
							tx_delay_counter	<= tx_delay_counter + 1;
						end if;
					
					when SEND_HEADER =>
						if m_axis_tready = '1' then
							tx_state	<= SEND_JSTK_X;
						end if;

					when SEND_JSTK_X =>
						if m_axis_tready = '1' then
							tx_state	<= SEND_JSTK_Y;
						end if;

					when SEND_JSTK_Y =>
						if m_axis_tready = '1' then
							tx_state	<= SEND_BUTTONS;
						end if;

					when SEND_BUTTONS =>
						if m_axis_tready = '1' then
							tx_state	<= DELAY;
						end if;

					end case;
			end if;
		end if;
	end process;

	-----------------------------------------------------------------------


	-- UART -> JSTK: LEDs color

	with rx_state select s_axis_tready <=
		'0'	when IDLE,
		'1'	when GET_HEADER,
		'1'	when GET_LED_R,
		'1'	when GET_LED_G,
		'1'	when GET_LED_B;

	process (aclk)
	begin
		if rising_edge(aclk) then
			if aresetn = '0' then
				
				rx_state			<= IDLE;

			else
				
				case rx_state is
					when IDLE =>
						rx_state		<= GET_HEADER;
					
					when GET_HEADER =>
						if s_axis_tvalid = '1' and s_axis_tdata = HEADER_CODE then
							rx_state	<= GET_LED_R;
						else
							-- Was expecting header, got something else: drop the value and stay in this state
						end if;

					when GET_LED_R =>
						if s_axis_tvalid = '1' then
							led_r_temp	<= s_axis_tdata;
							rx_state	<= GET_LED_G;
						end if;

					when GET_LED_G =>
						if s_axis_tvalid = '1' then
							led_g_temp	<= s_axis_tdata;
							rx_state	<= GET_LED_B;
						end if;

					when GET_LED_B =>
						if s_axis_tvalid = '1' then
							led_r		<= led_r_temp;
							led_g		<= led_g_temp;
							led_b		<= s_axis_tdata;
							rx_state	<= GET_HEADER;
						end if;

					end case;
			end if;
		end if;
	end process;

end Behavioral;
