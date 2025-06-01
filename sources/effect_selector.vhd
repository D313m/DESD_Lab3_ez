library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity effect_selector is
    generic(
        JOYSTICK_LENGHT  : integer := 10
    );
    Port (
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        effect : in STD_LOGIC;
        jstck_x : in STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        jstck_y : in STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
		
        volume : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        balance : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        lfo_period : out STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0)
    );
end effect_selector;

architecture Behavioral of effect_selector is

begin

	process(aclk, aresetn)
	begin
		if aresetn ='0' then
			volume <= (Others => '0');
			balance <= (Others => '0');
			lfo_period <= (Others => '1'); -- the longest period
			
		elsif rising_edge(aclk) then
		
			if effect = '1' then
				lfo_period <= jstck_y;
			else
				volume <= jstck_y;
				balance <= jstck_x;
			end if;
		
		end if;
	end process;

end Behavioral;
