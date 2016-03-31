library IEEE;                                -- make IEEE library visible
use IEEE.STD_LOGIC_1164.all;                 -- open up 1164 package
use IEEE.numeric_std.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;               -- open up TEXTIO package
use STD.TEXTIO.all;                          -- open up standard TEXTIO package
use work.SNES65816func.all;

entity TB_65816 is                         -- empty entity since test bench
	end entity TB_65816;                       -- end of empty entity

architecture TB_65816 of TB_65816 is      -- start of arc - declar area

	-- component stmt is entity stmt from design unit
    COMPONENT Soft_65C816
    PORT(
         clk : IN  std_logic;
         tru_clk : IN  std_logic;
         reset : IN  std_logic;
         Addr_Bus : OUT  std_logic_vector(23 downto 0);
         D_BUS : IN  std_logic_vector(31 downto 0);
         EMULATION_SELECT : OUT  std_logic;
         RDY : out  std_logic;
			DATA_RDY: in std_logic;
         REG_A : OUT  std_logic_vector(15 downto 0);
         REG_X : OUT  std_logic_vector(15 downto 0);
         REG_Y : OUT  std_logic_vector(15 downto 0);
         REG_SP : OUT  std_logic_vector(15 downto 0);
         REG_PC : OUT  std_logic_vector(15 downto 0);
         REG_Proc : OUT  std_logic_vector(7 downto 0);
         REG_DBR : OUT  std_logic_vector(7 downto 0);
         VPB : OUT  std_logic
        );
    END COMPONENT;
    
	 
	signal redirction_to_ram : std_logic_vector(23 downto 0) := (others => '0');

   --Inputs
   signal clk : std_logic := '0';
   signal tru_clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal D_BUS : std_logic_vector(31 downto 0) := (others => 'Z');
	signal DATA_RDY: std_logic := '1';

   --Outputs
   signal Addr_Bus : std_logic_vector(23 downto 0) := (others => '0');
   signal EMULATION_SELECT : std_logic;
   signal REG_A : std_logic_vector(15 downto 0);
   signal REG_X : std_logic_vector(15 downto 0);
   signal REG_Y : std_logic_vector(15 downto 0);
   signal REG_SP : std_logic_vector(15 downto 0);
   signal REG_PC : std_logic_vector(15 downto 0);
   signal REG_Proc : std_logic_vector(7 downto 0);
   signal REG_DBR : std_logic_vector(7 downto 0);
   signal VPB : std_logic;
	signal RDY : std_logic;

	type STATES is ( IDLE, S0, S1, S2, S3, S4);
-- declaration for states for state machine
	signal psr : STATES;                         -- instantiate present state register
	signal CNTR : INTEGER := 0;                  -- this counter has no real function, for info only
	signal CYCLE : INTEGER := 1;                 -- count cycles from beginning


type RamType is array(0 to 36) of std_logic_vector (7 downto 0);

impure function InitRamFromFile (RamFileName : in string) return RamType is
	FILE RamFile : text is in RamFileName;
	variable RamFileLine : line;
	variable RAM : RamType;
begin
	for I in RamType'range loop
		readline (RamFile, RamFileLine);
		hread (RamFileLine, RAM(I));
	end loop;
	return RAM;
end function;

signal RAM : RamType := InitRamFromFile("prog.hex");



begin                                        -- begin of the hardware description


	-- Instantiate the Unit Under Test (UUT)
   uut: Soft_65C816 PORT MAP (
          clk => clk,
          tru_clk => tru_clk,
          reset => reset,
          Addr_Bus => Addr_Bus,
          D_BUS => D_BUS,
          EMULATION_SELECT => EMULATION_SELECT,
          RDY => RDY,
			 DATA_RDY => DATA_RDY,
          REG_A => REG_A,
          REG_X => REG_X,
          REG_Y => REG_Y,
          REG_SP => REG_SP,
          REG_PC => REG_PC,
          REG_Proc => REG_Proc,
          REG_DBR => REG_DBR,
          VPB => VPB
        );

redirction_to_ram <= Addr_Bus;

TRU_CLOCK_PROC:                            
process                                    
begin                                      
    tru_clk <= '1';                        
    wait for 140 ns;                       
    tru_clk <= '0';                        
    wait for 140 ns;                       
end process;                               


CLOCK_PROC:                                	-- the clock process (100 MHz) 
process                                    	-- no sensitivity list....
begin                                      	-- start of the process
    CLK <= '1';                           	-- okay, start with clock high
    wait for 5 ns;                           -- wait 5 ns
    CLK <= '0';                           	-- then take clock low 
    wait for 5 ns;                           -- wait for another 5 ns
    CYCLE <= CYCLE + 1;                      -- increment the cycle counter
end process;                               	-- and do it all over....

reset <= '1' when CYCLE < 5 else '0';     	-- the reset statement (not synthesizable)

Arbitor:                           									-- process to handle file IO 
	process ( reset, clk ) is                      						-- sensitivity: clock
		file OUT_FILE : TEXT open WRITE_MODE is "Data.txt";  		-- declare an output file
		variable BUF : LINE;                       					-- a buffer to do work in
		variable DATA_STR : STD_LOGIC_VECTOR ( 31 downto 0 ); 		-- data string variable
		constant space : STRING ( 1 to 2 ) := "  ";
		constant HEADER : STRING ( 1 to 61 ) :=
		"REG_PC      REG_A     REG_X     REX_Y     REG_SP     REG_Proc";
		variable FLAG : BOOLEAN := TRUE;
		variable done : std_logic;
		variable cntr : integer := 0;
	begin

		if reset = '1' then
			psr <= IDLE;
		end if;
		if rising_edge(clk) then
			case psr is                       	     -- based on the contents of PSR, do....
				when IDLE =>                         -- from state IDLE,
					
					WRITE  ( BUF, HEADER );	   
					WRITELINE ( OUT_FILE, BUF);
					psr <= S0;                       -- go to state S0

				when S0 =>      

					DATA_RDY <= '1';
				
					if RDY = '1' then				-- when ready go to s1 
						psr <= S1;                      
					else 
						psr <= PSR;
					end if;
					
				when S1 =>                           
					if true  then	-- Read 32 bits into a variable
											--	based on what tested module needs	
											--cntr)
						 DATA_STR(31 downto 24)	:= RAM(cntr+0);
						 DATA_STR(23 downto 16)	:= RAM(cntr+1);
						 DATA_STR(15 downto 8)	:= RAM(cntr+2);
						 DATA_STR(7 downto 0)	:= RAM(cntr+3);
						 
						 
						 DATA_RDY <= '1';
						 
					else
						DATA_STR := X"eaeaeaea";
						psr <= S4;				-- When done w/ test, go to done.	
					end if;

					psr <= S2;

				when S2 =>
					
					DATA_RDY <= '1';
					cntr :=  cntr+2;
					D_BUS <=  DATA_STR;
					psr <= S3;

				when S3 =>
					
					DATA_RDY <= '0';
					HWRITE ( BUF,REG_PC);   WRITE  ( BUF, space );-- Write Reg values  
					HWRITE ( BUF,REG_A );   WRITE  ( BUF, space );-- to the line buffer
					HWRITE ( BUF,REG_X);    WRITE  ( BUF, space );-- 
					HWRITE ( BUF,REG_Y);    WRITE  ( BUF, space );-- 
					HWRITE ( BUF,REG_SP);   WRITE  ( BUF, space );-- 
					HWRITE ( BUF,REG_Proc); WRITE  ( BUF, space );-- 
					WRITELINE ( OUT_FILE, BUF);          -- then write whole thing out.

					psr <= S0;

				when S4 =>
				
					DATA_RDY <= '1';
					done := '1';

			end case;  	
		end if;                                
	end process;                               

end architecture TB_65816;
