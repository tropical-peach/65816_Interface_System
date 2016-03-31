-- file: Interface_Master_BD_clk_wiz_0_0_clk_wiz.vhd
-- 
-- (c) Copyright 2008 - 2013 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
------------------------------------------------------------------------------
-- User entered comments
------------------------------------------------------------------------------
-- None
--
------------------------------------------------------------------------------
--  Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
--   Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
------------------------------------------------------------------------------
-- CLK_OUT1____71.602______0.000______50.0______245.835____242.683
-- CLK_OUT2_____7.202______0.000______50.0______392.994____242.683
--
------------------------------------------------------------------------------
-- Input Clock   Freq (MHz)    Input Jitter (UI)
------------------------------------------------------------------------------
-- __primary_________100.000____________0.010

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity Interface_Master_BD_clk_wiz_0_0_clk_wiz is
port
 (-- Clock in ports
  clk_in1           : in     std_logic;
  -- Clock out ports
  clk_out1          : out    std_logic;
  clk_out2          : out    std_logic;
  -- Status and control signals
  resetn             : in     std_logic;
  locked            : out    std_logic
 );
end Interface_Master_BD_clk_wiz_0_0_clk_wiz;

architecture xilinx of Interface_Master_BD_clk_wiz_0_0_clk_wiz is
  -- Input clock buffering / unused connectors
  signal clk_in1_Interface_Master_BD_clk_wiz_0_0      : std_logic;
  -- Output clock buffering / unused connectors
  signal clkfbout_Interface_Master_BD_clk_wiz_0_0         : std_logic;
  signal clkfbout_buf_Interface_Master_BD_clk_wiz_0_0     : std_logic;
  signal clkfboutb_unused : std_logic;
  signal clk_out1_Interface_Master_BD_clk_wiz_0_0          : std_logic;
  signal clk_out1_Interface_Master_BD_clk_wiz_0_0_en_clk   : std_logic;
  signal clkout0b_unused         : std_logic;
  signal clk_out2_Interface_Master_BD_clk_wiz_0_0          : std_logic;
  signal clk_out2_Interface_Master_BD_clk_wiz_0_0_en_clk   : std_logic;
  signal clkout1b_unused         : std_logic;
  signal clkout2_unused   : std_logic;
  signal clkout2b_unused         : std_logic;
  signal clkout3_unused   : std_logic;
  signal clkout3b_unused  : std_logic;
  signal clkout4_unused   : std_logic;
  signal clkout5_unused   : std_logic;
  signal clkout6_unused   : std_logic;
  -- Dynamic programming unused signals
  signal do_unused        : std_logic_vector(15 downto 0);
  signal drdy_unused      : std_logic;
  -- Dynamic phase shift unused signals
  signal psdone_unused    : std_logic;
  signal locked_int : std_logic;
  -- Unused status signals
  signal clkfbstopped_unused : std_logic;
  signal clkinstopped_unused : std_logic;
  signal reset_high   : std_logic;
  signal seq_reg1       : std_logic_vector(7 downto 0) := (others => '0');
  signal seq_reg2       : std_logic_vector(7 downto 0) := (others => '0');
  attribute ASYNC_REG   : string;
  attribute ASYNC_REG of seq_reg1: signal is "TRUE";
  attribute keep: boolean;
  attribute keep of seq_reg1: signal is true;
  attribute ASYNC_REG of seq_reg2: signal is "TRUE";
  attribute keep of seq_reg2: signal is true;

begin


  -- Input buffering
  --------------------------------------
  clkin1_ibufg : IBUF
  port map
   (O => clk_in1_Interface_Master_BD_clk_wiz_0_0,
    I => clk_in1);



  -- Clocking PRIMITIVE
  --------------------------------------
  -- Instantiation of the MMCM PRIMITIVE
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused
  mmcm_adv_inst : MMCME2_ADV
  generic map
   (BANDWIDTH            => "HIGH",
    CLKOUT4_CASCADE      => FALSE,
    COMPENSATION         => "ZHOLD",
    STARTUP_WAIT         => FALSE,
    DIVCLK_DIVIDE        => 4,
    CLKFBOUT_MULT_F      => 36.875,
    CLKFBOUT_PHASE       => 0.000,
    CLKFBOUT_USE_FINE_PS => FALSE,
    CLKOUT0_DIVIDE_F     => 12.875,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT0_USE_FINE_PS  => FALSE,
    CLKOUT1_DIVIDE       => 128,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT1_USE_FINE_PS  => FALSE,
    CLKIN1_PERIOD        => 10.0)
  port map
    -- Output clocks
   (
    CLKFBOUT            => clkfbout_Interface_Master_BD_clk_wiz_0_0,
    CLKFBOUTB           => clkfboutb_unused,
    CLKOUT0             => clk_out1_Interface_Master_BD_clk_wiz_0_0,
    CLKOUT0B            => clkout0b_unused,
    CLKOUT1             => clk_out2_Interface_Master_BD_clk_wiz_0_0,
    CLKOUT1B            => clkout1b_unused,
    CLKOUT2             => clkout2_unused,
    CLKOUT2B            => clkout2b_unused,
    CLKOUT3             => clkout3_unused,
    CLKOUT3B            => clkout3b_unused,
    CLKOUT4             => clkout4_unused,
    CLKOUT5             => clkout5_unused,
    CLKOUT6             => clkout6_unused,
    -- Input clock control
    CLKFBIN             => clkfbout_buf_Interface_Master_BD_clk_wiz_0_0,
    CLKIN1              => clk_in1_Interface_Master_BD_clk_wiz_0_0,
    CLKIN2              => '0',
    -- Tied to always select the primary input clock
    CLKINSEL            => '1',
    -- Ports for dynamic reconfiguration
    DADDR               => (others => '0'),
    DCLK                => '0',
    DEN                 => '0',
    DI                  => (others => '0'),
    DO                  => do_unused,
    DRDY                => drdy_unused,
    DWE                 => '0',
    -- Ports for dynamic phase shift
    PSCLK               => '0',
    PSEN                => '0',
    PSINCDEC            => '0',
    PSDONE              => psdone_unused,
    -- Other control and status signals
    LOCKED              => locked_int,
    CLKINSTOPPED        => clkinstopped_unused,
    CLKFBSTOPPED        => clkfbstopped_unused,
    PWRDWN              => '0',
    RST                 => reset_high);

  reset_high <= not resetn; 
  locked <= locked_int;

  -- Output buffering
  -------------------------------------

  clkf_buf : BUFG
  port map
   (O => clkfbout_buf_Interface_Master_BD_clk_wiz_0_0,
    I => clkfbout_Interface_Master_BD_clk_wiz_0_0);



  clkout1_buf : BUFGCE
  port map
   (O   => clk_out1,
    CE  => seq_reg1(7),
    I   => clk_out1_Interface_Master_BD_clk_wiz_0_0);

  clkout1_buf_en : BUFH
  port map
   (O   => clk_out1_Interface_Master_BD_clk_wiz_0_0_en_clk,
    I   => clk_out1_Interface_Master_BD_clk_wiz_0_0);
   
  process(clk_out1_Interface_Master_BD_clk_wiz_0_0_en_clk)
  begin
     if clk_out1_Interface_Master_BD_clk_wiz_0_0_en_clk'event and clk_out1_Interface_Master_BD_clk_wiz_0_0_en_clk = '1' then
        seq_reg1 <= seq_reg1(6 downto 0) & locked_int;
     end if;
  end process;


  clkout2_buf : BUFGCE
  port map
   (O   => clk_out2,
    CE  => seq_reg2(7),
    I   => clk_out2_Interface_Master_BD_clk_wiz_0_0);

  clkout2_buf_en : BUFH
  port map
   (O   => clk_out2_Interface_Master_BD_clk_wiz_0_0_en_clk,
    I   => clk_out2_Interface_Master_BD_clk_wiz_0_0);
   
  process(clk_out2_Interface_Master_BD_clk_wiz_0_0_en_clk)
  begin
     if clk_out2_Interface_Master_BD_clk_wiz_0_0_en_clk'event and clk_out2_Interface_Master_BD_clk_wiz_0_0_en_clk = '1' then
        seq_reg2 <= seq_reg2(6 downto 0) & locked_int;
     end if;
  end process;
   

end xilinx;
