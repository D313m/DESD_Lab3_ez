library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_level_controller is
	generic(
		NUM_LEDS        : positive := 16;
		CHANNEL_LENGHT  : positive := 24;
		refresh_time_ms : positive := 1;
		clock_period_ns : positive := 10
	);
	Port (
		aclk            : in  std_logic;
		aresetn         : in  std_logic;
		
		led             : out std_logic_vector(NUM_LEDS - 1 downto 0);
		
		s_axis_tvalid   : in  std_logic;
		s_axis_tdata    : in  std_logic_vector(CHANNEL_LENGHT - 1 downto 0);
		s_axis_tlast    : in  std_logic;
		s_axis_tready   : out std_logic
	);
end led_level_controller;

architecture Behavioral of led_level_controller is
	
	type STATUS_t is (WAITING, GET_L, GET_R, LIGHT);
	signal status : STATUS_t := GET_L;
	
	constant MAX_COUNTER : integer := (refresh_time_ms * 10**6)/clock_period_ns - 1;
	signal counter : integer range 0 to MAX_COUNTER := 0;
	
	
	signal L_data :   signed(CHANNEL_LENGHT - 1 downto 0);
	signal R_data :   signed(CHANNEL_LENGHT - 1 downto 0);
	signal avg    : unsigned(CHANNEL_LENGHT - 1 downto 0);
	
	signal on_led_num : integer range 0 to NUM_LEDS-1;
	
begin
	
	process (aclk, aresetn)
		variable L_data_uns : unsigned(CHANNEL_LENGHT downto 0);
		variable R_data_uns : unsigned(CHANNEL_LENGHT downto 0);
		variable sum        : unsigned(CHANNEL_LENGHT downto 0);
	begin
		if aresetn = '0' then
			status     <= GET_L;
			counter    <= 0;
			L_data     <= (Others => '0');
			R_data     <= (Others => '0');
			led        <= (Others => '0');
			avg        <= (Others => '0');
			on_led_num <= 0;
			
		elsif rising_edge(aclk) then
		
			case status is
				
				when WAITING =>
					
					if counter < max_counter then
						counter <= counter + 1;
					else
						counter <= 0;
						status <= GET_L;
					end if;
				
				when GET_L =>
					
					if s_axis_tvalid = '1' and s_axis_tlast = '0' then
						L_data <= signed(s_axis_tdata);
						status <= GET_R;
					else
						status <= GET_L;
					end if;
				
				when GET_R =>
					
					if s_axis_tvalid = '1' then -- tlast = '1' follows tlast = '0'
						R_data <= signed(s_axis_tdata);
						status <= LIGHT;
					else
						status <= GET_R;
					end if;					
				
				when LIGHT =>
					
					L_data_uns := unsigned(abs(L_data(L_data'HIGH) & L_data));
					R_data_uns := unsigned(abs(R_data(R_data'HIGH) & R_data));
					sum        := L_data_uns + R_data_uns;
					avg        <= sum(sum'HIGH downto 1); -- /2
					
					on_led_num <= to_integer(avg) / (2**(CHANNEL_LENGHT - 1) / NUM_LEDS);
					
					for i in 0 to NUM_LEDS - 1 loop
						if on_led_num > i then
							led(i) <= '1';
						else
							led(i) <= '0';
						end if;
					end loop;
					
					status <= WAITING;
				
				when Others =>
					
			end case;
			
		end if;
	end process;
	
	s_axis_tready <= '1';
	
end Behavioral;