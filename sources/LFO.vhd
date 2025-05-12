    library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    generic(
        CHANNEL_LENGHT  : integer := 24;
        JOYSTICK_LENGHT  : integer := 10;
        CLK_PERIOD_NS   : integer := 10;
        TRIANGULAR_COUNTER_LENGHT    : integer := 10 -- Triangular wave period length
    );
    Port (
        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            lfo_period      : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic;
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
end entity LFO;

architecture Behavioral of LFO is

begin  

end architecture;