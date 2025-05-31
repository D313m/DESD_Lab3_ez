library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity led_controller is
	Generic (
		LED_WIDTH	: positive := 8
	);
	Port (
		mute_enable	: in std_logic;
		filter_enable	: in std_logic;

		led_r		: out std_logic_vector(LED_WIDTH-1 downto 0);
		led_g		: out std_logic_vector(LED_WIDTH-1 downto 0);
		led_b		: out std_logic_vector(LED_WIDTH-1 downto 0)
	);
end led_controller;

architecture Behavioral of led_controller is 

	signal RED_on : std_logic;
	signal GREEN_on : std_logic;
	signal BLUE_on : std_logic;

begin

	RED_on <= mute_enable;
	GREEN_on <= (not mute_enable) and (not filter_enable);
	BLUE_on <= (not mute_enable) and filter_enable;
	
	led_r <= (Others => RED_on);
	led_g <= (Others => GREEN_on);
	led_b <= (Others => BLUE_on);

end Behavioral;
