library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity edge_detector_toggle is
	generic (
		EDGE_RISING		: boolean := true
	);
	port (
		input_signal	: in std_logic;
		clk				: in std_logic;
		reset			: in std_logic;
		output_signal	: out std_logic
	);
end edge_detector_toggle;

architecture Behavioral of edge_detector_toggle is

begin

end Behavioral;
