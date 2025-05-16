library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity volume_controller is
  generic (
    TDATA_WIDTH     : positive := 24;              -- Audio data width (24 bits)
    VOLUME_WIDTH    : positive := 10;              -- Joystick Y-axis input width (0-1023)
    VOLUME_STEP_2   : positive := 6;               -- Volume change every 2^6 = 64 joystick steps
    HIGHER_BOUND    : integer := 2**23 - 1;        -- Max 24-bit signed value (+8388607)
    LOWER_BOUND     : integer := -2**23            -- Min 24-bit signed value  (-8388608)
  );
  port (
    -- Clock & Reset 
    aclk            : in  std_logic;
    aresetn         : in  std_logic;

    -- AXI4-Stream Slave (input)
    s_axis_tvalid   : in  std_logic;
    s_axis_tdata    : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
    s_axis_tlast    : in  std_logic;
    s_axis_tready   : out std_logic;

    -- AXI4-Stream Master (output)
    m_axis_tvalid   : out std_logic;
    m_axis_tdata    : out std_logic_vector(TDATA_WIDTH-1 downto 0);
    m_axis_tlast    : out std_logic;
    m_axis_tready   : in  std_logic;

    -- Joystick Y-axis volume input
    volume          : in  std_logic_vector(VOLUME_WIDTH-1 downto 0)
  );
end volume_controller;

architecture Behavioral of volume_controller is

  -- Output buffer (1 sample)
  signal out_data_reg  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
  signal out_tlast_reg : std_logic := '0';
  signal out_valid_reg : std_logic := '0';

  -- Internal ready signal to avoid reading from 'out' port
  signal axis_ready    : std_logic;

begin

  -- Output assignments
  m_axis_tdata  <= out_data_reg;
  m_axis_tlast  <= out_tlast_reg;
  m_axis_tvalid <= out_valid_reg;

  -- Ready to receive new input if output is free or being consumed
  axis_ready    <= '1' when (out_valid_reg = '0') or 
                            ((out_valid_reg = '1') and (m_axis_tready = '1'))
                   else '0';
  s_axis_tready <= axis_ready;

  process(aclk)
    variable vol_int      : integer;
    variable offset       : integer;
    variable exp_val      : integer;                                -- Gain exponent (-8 to +7)
    variable sample_in    : signed(TDATA_WIDTH-1 downto 0);
    variable extended     : signed(TDATA_WIDTH+6-1 downto 0);        -- For safe shifting
    variable shifted_val  : signed(TDATA_WIDTH+6-1 downto 0);
    variable result       : signed(TDATA_WIDTH-1 downto 0);
    variable temp_int     : integer;
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        -- Reset output state
        out_valid_reg <= '0';
        out_data_reg  <= (others => '0');
        out_tlast_reg <= '0';

      else
        -- Free output buffer if downstream is ready
        if (out_valid_reg = '1') and (m_axis_tready = '1') then
          out_valid_reg <= '0';
        end if;

        -- Accept new input if valid and ready
        if (s_axis_tvalid = '1') and (axis_ready = '1') then
          -- Convert volume input to integer and center it
          vol_int := to_integer(unsigned(volume));              -- 0-1023
          offset  := vol_int - (2 ** (VOLUME_WIDTH - 1));       --  512 center

          -- Used division instead of sra for compatibility (Vivado handles as shift since denominator is constant)
          exp_val := offset / (2 ** VOLUME_STEP_2);             -- offset / 64

          -- Clamp exponent
          if exp_val >  7 then exp_val :=  7; end if;
          if exp_val < -8 then exp_val := -8; end if;

          -- In order to avoid overflow, audio sample should be extended
          sample_in := signed(s_axis_tdata);
          extended  := resize(sample_in, extended'length);

          -- Apply gain
          if exp_val >= 0 then
            shifted_val := shift_left(extended, exp_val);    -- Amplify
          else
            shifted_val := shift_right(extended, -exp_val);  -- Attenuate
          end if;

          -- Clip to 24-bit range
          temp_int := to_integer(shifted_val);
          if temp_int > HIGHER_BOUND then
            temp_int := HIGHER_BOUND;
          elsif temp_int < LOWER_BOUND then
            temp_int := LOWER_BOUND;
          end if;

          result := to_signed(temp_int, TDATA_WIDTH);

          -- Write to output buffer
          out_data_reg  <= std_logic_vector(result);
          out_tlast_reg <= s_axis_tlast;
          out_valid_reg <= '1';
        end if;
      end if;
    end if;
  end process;

end Behavioral;
