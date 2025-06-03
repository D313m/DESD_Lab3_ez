-- This module converts the unsigned joystick outputs into signed values
-- to avoid doing it several times downstream. It alternates between 
-- converting the x and y values.
-- E.G.: [0-1023] => [-512, 511]

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
	signal select_sig      : std_logic;                        -- Switches between x and y conversion
	signal extended_signed : signed(JOYSTICK_LENGHT downto 0); -- 1 bit more to store as signed value
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
			
			if select_sig = '1' then -- Stores x
				extended_signed <= signed('0' & jstck_x);
			else                     -- Stores y
				extended_signed <= signed('0' & jstck_y);
			end if;
			
			centered_signed := resize(extended_signed - 2**(JOYSTICK_LENGHT - 1), JOYSTICK_LENGHT);
			
			                                          -- With effect high, ONLY the lfo_period must be updated.
			if effect = '1' and select_sig = '1' then -- Outputs y (not converted to signed)
				lfo_period <= std_logic_vector(extended_signed(lfo_period'RANGE));
			elsif select_sig = '1' then               -- Also effect = '0'. Outputs y (converted to signed)
				volume     <= std_logic_vector(centered_signed);
			elsif effect = '0' then                   -- Also select_sig = '0'. Outputs x (converted to signed)
				balance    <= std_logic_vector(centered_signed);
			end if;
		
		end if;
	end process;

end Behavioral;