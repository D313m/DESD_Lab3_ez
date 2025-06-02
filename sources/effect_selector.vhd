library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity effect_selector is
	generic(
		JOYSTICK_LENGHT : integer := 10
	);
	Port (
		aclk       : in  std_logic;
		aresetn    : in  std_logic;
		
		effect     : in  std_logic;
		jstck_x    : in  std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
		jstck_y    : in  std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
		
		volume     : out std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
		balance    : out std_logic_vector(JOYSTICK_LENGHT - 1 downto 0);
		lfo_period : out std_logic_vector(JOYSTICK_LENGHT - 1 downto 0)
	);
end effect_selector;

architecture Behavioral of effect_selector is
	signal select_sig      : std_logic;
	signal extended_signed : signed(JOYSTICK_LENGHT downto 0); -- 1 bit more
begin
	
	process(aclk, aresetn)
		variable centered_signed : signed(JOYSTICK_LENGHT - 1 downto 0);
	begin
		if aresetn = '0' then
			
			volume     <= (Others => '0');
			balance    <= (Others => '0');
			lfo_period <= (Others => '1'); -- The longest period
			
			extended_signed <= (Others => '0');
			select_sig <= '0';
			
		elsif rising_edge(aclk) then
			
			select_sig <= not select_sig;
			
			if select_sig = '1' then
				extended_signed <= signed('0' & jstck_x);
			else
				extended_signed <= signed('0' & jstck_y);
			end if;
			
			centered_signed := resize(extended_signed - 2**(JOYSTICK_LENGHT - 1), JOYSTICK_LENGHT);
		
			if effect = '1' and select_sig = '1' then
				lfo_period <= std_logic_vector(extended_signed(lfo_period'RANGE)); -- Original value
			elsif select_sig = '1' then
				volume     <= std_logic_vector(centered_signed);
			elsif effect = '0' then
				balance    <= std_logic_vector(centered_signed);
			end if;
		
		end if;
	end process;

end Behavioral;