library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
  generic (
    TDATA_WIDTH   : integer := 24;
    VOLUME_WIDTH  : integer := 10;
    VOLUME_STEP_2 : integer := 6;
    HIGHER_BOUND  : integer := 8388607;
    LOWER_BOUND   : integer := -8388608
  );
  port (
    aclk          : in  std_logic;
    aresetn       : in  std_logic;

    s_axis_tvalid : in  std_logic;
    s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
    s_axis_tlast  : in  std_logic;
    s_axis_tready : out std_logic;

    m_axis_tvalid : out std_logic;
    m_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
    m_axis_tlast  : out std_logic;
    m_axis_tready : in  std_logic;

    volume        : in  std_logic_vector(VOLUME_WIDTH-1 downto 0)
  );
end volume_controller;

architecture Behavioral of volume_controller is
  -- Constants
  constant MIDPOINT  : integer := 2 ** (VOLUME_WIDTH - 1);
  constant STEP_SIZE : integer := 2 ** VOLUME_STEP_2;
  constant EXP_MIN   : integer := -8;
  constant EXP_MAX   : integer := 7;

  -- Stage 1 registers
  signal stage1_valid : std_logic := '0';
  signal stage1_data  : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
  signal stage1_exp   : integer range -8 to 7 := 0;
  signal stage1_last  : std_logic := '0';

  -- Stage 2 registers (output)
  signal stage2_valid : std_logic := '0';
  signal stage2_data  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
  signal stage2_last  : std_logic := '0';

  -- Internal ready signal
  signal s_axis_tready_int : std_logic;

begin

  -- External ready port driven by internal logic
  s_axis_tready <= s_axis_tready_int;

  -- AXI output interface
  m_axis_tvalid <= stage2_valid;
  m_axis_tdata  <= stage2_data;
  m_axis_tlast  <= stage2_last;

  -- Ready handshake logic
  s_axis_tready_int <= '1' when (stage1_valid = '0') or 
                              ((stage1_valid = '1') and (stage2_valid = '0') and (m_axis_tready = '1'))
                       else '0';

  process(aclk)
    variable vol_val    : integer;
    variable offset     : integer;
    variable exp_val    : integer;
    variable extended   : signed(31 downto 0);
    variable shifted    : signed(31 downto 0);
    variable temp_int   : integer;
    variable clipped    : signed(TDATA_WIDTH-1 downto 0);
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        stage1_valid <= '0';
        stage2_valid <= '0';
        stage2_data  <= (others => '0');
        stage2_last  <= '0';
      else
        -- Stage 2 output logic
        if stage1_valid = '1' and ((stage2_valid = '0') or (m_axis_tready = '1')) then
          extended := resize(stage1_data, 32);

          -- Exponential shift (volume control)
          if stage1_exp >= 0 then
            shifted := extended sll stage1_exp;
          else
            shifted := shift_right(extended, -stage1_exp);
          end if;

          -- Clipping
          temp_int := to_integer(shifted);
          if temp_int > HIGHER_BOUND then
            temp_int := HIGHER_BOUND;
          elsif temp_int < LOWER_BOUND then
            temp_int := LOWER_BOUND;
          end if;
          clipped := to_signed(temp_int, TDATA_WIDTH);

          stage2_data  <= std_logic_vector(clipped);
          stage2_last  <= stage1_last;
          stage2_valid <= '1';
          stage1_valid <= '0';
        elsif m_axis_tready = '1' then
          stage2_valid <= '0'; -- output consumed
        end if;

        -- Stage 1 input logic
        if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
          stage1_data <= signed(s_axis_tdata);
          stage1_last <= s_axis_tlast;

          vol_val := to_integer(unsigned(volume));
          offset  := vol_val - MIDPOINT;
          exp_val := offset / STEP_SIZE;

          if exp_val > EXP_MAX then
            stage1_exp <= EXP_MAX;
          elsif exp_val < EXP_MIN then
            stage1_exp <= EXP_MIN;
          else
            stage1_exp <= exp_val;
          end if;

          stage1_valid <= '1';
        end if;
      end if;
    end if;
  end process;

end Behavioral;
