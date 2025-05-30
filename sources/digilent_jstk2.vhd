library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity digilent_jstk2 is
	generic (
		DELAY_US      : integer := 25;           -- Delay [us] between two packets
		CLKFREQ       : integer := 100_000_000;  -- Frequency of the aclk signal [Hz]
		SPI_SCLKFREQ  : integer := 50_000        -- Frequency of the SPI SCLK clock signal [Hz]
	);
	Port ( 
		aclk          : in  std_logic;
		aresetn	      : in  std_logic;
		
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
	-- Code for the SetLEDRGB command, as per the JSTK2 datasheet.
	constant CMDSETLEDRGB : std_logic_vector(7 downto 0) := x"84";
	
	
begin
	
	
	
end architecture;