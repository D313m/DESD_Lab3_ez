library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller is
	generic (
		TDATA_WIDTH		: positive := 24;
		BALANCE_WIDTH	: positive := 10;
		BALANCE_STEP_2	: positive := 6		-- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is

	type DATA_BUFFER_t is array (2**((BALANCE_WIDTH-BALANCE_STEP_2)-1)-1 downto 0) of signed(TDATA_WIDTH-1 downto 0);
	signal L_data : DATA_BUFFER_t;
	signal R_data : DATA_BUFFER_t;
	
	signal balance_sig : std_logic_vector(BALANCE_WIDTH-1 downto 0);
	signal balance_sig_normalized : integer range (- (2**(BALANCE_WIDTH-1))) to (2**(BALANCE_WIDTH-1));

begin

	process(aclk, aresetn)
	begin
		if aresetn = '0' then
			L_data <= (Others => (Others => '0'));
			R_data <= (Others => (Others => '0'));
			balance_sig <= std_logic_vector(to_signed(2**(BALANCE_WIDTH-1), balance_sig'length));
			balance_sig_normalized <= 0;
			
		elsif rising_edge(aclk) then
			balance_sig <= balance;
			balance_sig_normalized <= to_integer(signed('0' & balance_sig) - (2**(BALANCE_WIDTH-1)));
			
			if m_axis_tready = '1' and s_axis_tvalid = '1' then
			
				if s_axis_tlast = '0' then -- Left data
					L_data(0) <= signed(s_axis_tdata);
					m_axis_tdata <= std_logic_vector(L_data(L_data'HIGH));
					
					for i in 0 to L_data'HIGH-1 loop
						if balance_sig_normalized > + ((2**BALANCE_STEP_2) * i + (2**(BALANCE_STEP_2-1))) then -- in our case balance_sig_normalized > + (64 * i + 32)
							L_data(i+1) <= shift_right(L_data(i), 1); -- shift a destra aritmetico (divisione per 2 ottimizzata per signed)
						else
							L_data(i+1) <= L_data(i);
						end if;
					end loop;
					
				else --Right data
					R_data(0) <= signed(s_axis_tdata);
					m_axis_tdata <= std_logic_vector(R_data(R_data'HIGH));
					
					for i in 0 to R_data'HIGH-1 loop
						if balance_sig_normalized < - ((2**BALANCE_STEP_2) * i + (2**(BALANCE_STEP_2-1))) then -- in our case balance_sig_normalized < - (64 * i + 32)
							R_data(i+1) <= shift_right(R_data(i), 1); -- shift a destra aritmetico (divisione per 2 ottimizzata per signed)
						else
							R_data(i+1) <= R_data(i);
						end if;
					end loop;
					
				end if;
				m_axis_tlast <= s_axis_tlast;
				
			end if;
			
		end if;
	end process;

	m_axis_tvalid <= s_axis_tvalid;
	s_axis_tready <= m_axis_tready;

end Behavioral;
