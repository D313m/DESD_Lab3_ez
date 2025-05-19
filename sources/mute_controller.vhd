library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
	Generic (
		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		mute			: in std_logic
	);
end mute_controller;

architecture Behavioral of mute_controller is

type STATUS_t is (MUTE_state, ALL_PASS_state);
signal status : STATUS_t := ALL_PASS_state;

signal m_axis_tvalid_sig : std_logic;

begin

	process (aclk, aresetn)
	begin
		if aresetn = '0' then
			status <= ALL_PASS_state;
			
		elsif rising_edge(aclk) then
			
			case status is 
			
				when ALL_PASS_state =>
					if mute = '1' and (m_axis_tready = '1' or m_axis_tvalid_sig = '0') then
						status <= MUTE_state;
					else
						status <= ALL_PASS_state;
					end if;
					
				when MUTE_state =>
					if mute = '0' and m_axis_tready = '1' then
							status <= ALL_PASS_state;
					else
						status <= MUTE_state;
					end if;
				
				when Others =>
				
			end case;
		end if;
	end process;
	
	
	m_axis_tvalid 		<= m_axis_tvalid_sig;
	
	m_axis_tvalid_sig 	<= s_axis_tvalid 	when status = ALL_PASS_state else '1';
	m_axis_tdata 		<= s_axis_tdata 	when status = ALL_PASS_state else (Others => '0');
	s_axis_tready 		<= m_axis_tready;
	m_axis_tlast 		<= s_axis_tlast;

end Behavioral;
