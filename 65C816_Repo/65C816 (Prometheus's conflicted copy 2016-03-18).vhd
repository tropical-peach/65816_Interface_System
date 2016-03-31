----------------------------------------------------------------------------------
-- Company:     Open Source
-- Engineer:    Steven T. Seppala ( rad- )
-- 
-- Create Date: 01/26/2016 03:26:56 PM
-- Design Name: 
-- Module Name: 65C816 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
--      This is a soft-core implementation of a 65C816. There will be initally 92
--of the 256 OpCodes useable. Please refer to DOC 1A for reference. 
-- 
-- Dependencies: 
--      For testing purposes there will be an AXI interface into this module.
--This should be provided with all the source HDL.
--If this module is being used in conjunction with another module and there is no need
--to access or view the inner workings of this module, no other dependancies occour.
-- 
-- Revision:    V .1 -- 26 Jan 2016  STS
--
-- Revision 0.01 - File Created
-- Additional Comments:
-- 		The SNES CPU (65c816) uses little endian.
--	Revision 0.5 - Decode Table and Addressing Modes
--		The decode process and addressing mode assigning table
--		processes have been crated. 
--			NOTE : Memory accesses will be passed from this 
--						module to a C_FLAG program for reading/writing.
--	Revision 1.0 -	18 Feb 2016
--		Main Modules finished. 
--	Revision 1.1 - 3 March 2016
--		Tests passed. Main is now implemented.
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

use work.SNES65816func.all;

entity Soft_65C816 is
	Port ( clk : in STD_LOGIC;							-- 	Main CLK for system
		   tru_clk	: in std_logic;						--	True clk for system
		   reset		: in std_logic;					--	Reset Signal
		   Addr_Bus : out STD_LOGIC_VECTOR (23 downto 0);--	Address Bus
		   D_BUS : in STD_LOGIC_VECTOR (31 downto 0);	--	Data Bus
		   EMULATION_SELECT : out STD_LOGIC;			--	Emulation Bit
		   RDY : out STD_LOGIC;
			DATA_RDY: in STD_LOGIC;
		   REG_A 	:out	std_logic_vector(15 downto 0);
		   REG_X 	:out	std_logic_vector(15 downto 0);
		   REG_Y 	:out	std_logic_vector(15 downto 0);
		   REG_SP 	:out	std_logic_vector(15 downto 0);
		   REG_PC 	:out	std_logic_vector(15 downto 0);
			REG_Proc :out	std_logic_vector(7 downto 0);
			REG_DBR  :out	std_logic_vector(7 downto 0);
		   VPB : out STD_LOGIC);
end Soft_65C816;

architecture Behavioral of Soft_65C816 is

	--state machine states 
	type state_machine_states is (s0, s1, s2, s3, s4, s5 , sc, sa, sm, sp, sf, ss, sn, se, si, calculate_memory_pointer, s6);
	signal state : state_machine_states;

	--One hot sounter for state machine location/control
	signal state_machine_onehot : std_logic_vector (15 downto 0);	


	--chunk pull vector
	signal chunk_pull : std_logic_vector (31 downto 0);

	--vector with info about the opcode
	signal instruction_info : std_logic_vector (11 downto 0);

	signal op_code : std_logic_vector (7 downto 0);

	--	This will have the instructions arguments assigned to it.
	signal instrction_args : std_logic_vector (31 downto 0);


	--	This signal must be run with a 3.58 MHz CLK.
	--	It is just a counter, but it must count at 3.58 MHz.
	signal tru_cpu : std_logic_vector (3 downto 0);
	
	-- This is essentially a latch enable, 
	--	it will count for as many cycles as the
	--	operation would take on a true 65816
	signal tru_clk_cntr : std_logic_vector(3 downto 0);


	--	This will hold the instruction size, so the PC can correctly
	--	be incrimented.
	signal instruction_size : std_logic_vector (3 downto 0);

	--	Memory pointer for pulling and pushing values
	signal memory_pointer : std_logic_vector ( 23 downto 0);


	--	This signal holds the values from the memory locations
	--	requested.
	signal requested_values : std_logic_vector (31 downto 0);

	--	This will hold type info so the correct
	--	execution state can be determined.
	signal type_info : std_logic_vector (3 downto 0);

	--
	--	Process Control Signals
	--
	signal addressing_done, addressing_on, decode_on, decode_done, memory_calculate_done, memory_calculate_on : STD_LOGIC;
	signal memory_done:std_logic;
	signal math_done : std_logic;
	signal pc_done : std_logic;
	signal flag_done : std_logic;
	signal store_back: std_logic;
	signal push_to_stack : std_logic;
	signal ready_up : std_logic;
	signal stack_done: std_logic;
	signal exchange_done: std_logic;
	signal data_enable : std_logic;


	--
	--	REGISTER DECLARATIONS
	--

	--	Program Counter	: PC
	--	PC Bank Register	: PBR
	signal PC : std_logic_vector (23 downto 0);
	alias PBR : std_logic_vector (7 downto 0) is PC (23 downto 16);
	alias ProgramCntr : std_logic_vector (15 downto 0) is PC (15 downto 0);

	--	Accumulator 		: A_REG
	--	Direct Page Register: DP
	--	Stack Pointer 		: SP
	--	X & Y_REG Are Index Registers
	signal A_REG, DP, StackPointer, X_REG, Y_REG : std_logic_vector ( 15 downto 0);

	--	StackPointer is vaid from 00:0000 to 00:FFFF

	--	Processor Status	: P
	--	Data Bank Register	: DBR
	signal P		: std_logic_vector ( 7 downto 0);
	signal DBR 	: std_logic_vector ( 7 downto 0);

	alias N 			: STD_LOGIC is P(7);	-- Negative Flag
	alias V 			: STD_LOGIC is P(6);	-- Overflow Flag
	alias M 			: STD_LOGIC is P(5);	-- Memory Select
	alias X_FLAG 	: STD_LOGIC is P(4);	-- Index Register
	alias D_FLAG 	: STD_LOGIC is P(3);	-- Decimal Mode
	alias I 			: STD_LOGIC is P(2);	-- IRQ Disable
	alias Z 			: STD_LOGIC is P(1);	-- Zero Result
	alias C_FLAG 	: STD_LOGIC is P(0);	-- Carry Flag / Emulation Mode

--
--	END REGISTER DECLARATIONS
--

--
--	Memory signals
--
	signal 	effective_memory_pointer 	: std_logic_vector (23 downto 0);
	signal	write_back_location			: std_logic_vector (23 downto 0);
	signal 	write_back_value 				: std_logic_vector(15 downto 0);
	signal 	write_back_bank 				: std_logic_vector(7 downto 0);

	signal 	adr_type 						: integer range 0 to 25;
	signal 	push_val							: std_logic_vector(23 downto 0);
	signal 	read_out							: std_logic_vector(15 downto 0);
	signal 	read_out_bank					: std_logic_vector(7 downto 0);
	signal 	address_out						: std_logic_vector(23 downto 0);


--
--
--		Constant Signals
--
--
	constant zeros : std_logic_vector (15 downto 1) := ( B"0000_0000_0000_000");



begin


	Addr_Bus<=	address_out;
	REG_A 	<=	A_REG;
	REG_X 	<=	X_REG;
	REG_Y 	<=	Y_REG;
	REG_SP 	<=	StackPointer;
	REG_PC 	<=	ProgramCntr;
	REG_Proc <=	P;
	REG_DBR  <=	DBR;
	--
	--	This is the true CPU clock for the processor
	--	It runs at 3.58 MHz and allows s6 to continue 
	--		to s1.
slow_clock:
process(tru_clk, clk) is

begin

	if reset = '1' then 
		tru_clk_cntr <= (others => '0');
		ready_up <= '0';
	end if;


	if rising_edge(clk) then
		if (tru_clk_cntr = tru_cpu) and rising_edge(tru_clk) then
			ready_up <= '1' ;
		else 
			ready_up <= '0';
		end if;
	elsif falling_edge(clk) then
		if ready_up ='1' then
			tru_clk_cntr <= (others => '0');
		end if;
	end if;
		
	if rising_edge(tru_clk) then
		tru_clk_cntr <= std_logic_vector(unsigned(tru_clk_cntr) + 1);
	end if;
		
end process;


	--
	--	This is a 16 bit microprocessor with variable length instructions, the PC will 
	--	depend on the current instruction size.
	--	Thus the PC will get 
	--
	--

	state_machine:
	process (clk, reset) is

		variable effective_memeory_pointer_temp : std_logic_vector (23 downto 0);
		variable pointer_calculation_done : std_logic;
		variable math_temp	: std_logic_vector (16 downto 0);
		variable stack_temp  : std_logic_vector (16 downto 0);
		variable xfr_temp	 	: std_logic_vector (16 downto 0);
		variable mem_temp	 	: std_logic_vector (16 downto 0);
		variable flag_temp   : std_logic_vector (16 downto 0);

	begin


			
		if  reset = '1' then
			--TODO: RESET
			state <= s0;						-- reset to s0
			chunk_pull <= (others => 'Z');		-- clear chunk pull
			op_code <= (others => 'Z');			-- set opcode hi-Z
			StackPointer <= X"0100";								--	Initialize Stack pointer
			A_REG <= (others => '0');
			X_REG	<= (others => '0');
			Y_REG	<= (others => '0');
			PC	 <=	(others => '0');
			DBR <= 	X"00";
			DP	 <=	X"0000";
			N	 <= 	'0';
			V	 <=	'0';
			M	 <=	'1';
			X_FLAG	 <=	'1';
			D_FLAG	 <=	'0';
			I	 <=	'1';
			Z	 <=	'0';
			C_FLAG	 <=	'1';	-- This is the emulation flag on reset.


		elsif rising_edge(clk) then

			case state is 
				when s0 =>
					if state_machine_onehot = "0000000000000001" then
						state <= s1;
					else
						state <= s0;
					end if;
					
					state_machine_onehot <= "0000000000000001";
					write_back_value 	<=X"0000";
					write_back_bank	<=X"00";
					address_out			<=PC;
					rdy <= '1';

				when s1 =>
					if state_machine_onehot = "0000000000000010"  then
						state <= s2;
					else
						state <= s1;
					end if;
					
					rdy <= '0';
					data_enable <= '1';
						
					if data_rdy ='0' and chunk_pull /= "ZZZZZZZZZZZZZZZZZ" then
						chunk_pull <= D_BUS;
						state_machine_onehot <= "0000000000000010";
					end if;


				when s2 =>

					if ((addressing_done = '1') and (decode_done = '1') and (state_machine_onehot = "0000000000000100")) then
						state <= s3;
					else
						state <= s2;
					end if;
					
				
					addressing_on <= '1';
					decode_on <= '1';
					--	This should send the OPCode from chunkpull
					--	to the opcode_info process, which inturn 
					--	will give us everything we need to know about how
					--	to execute the instruction.
					if data_enable = '1' then 
						op_code <= chunk_pull(31 downto 24);
						state_machine_onehot <= "0000000000000100";
						data_enable <= '0';
					end if;

				when s3 =>
					if state_machine_onehot = "0000000000001000" then
						state <= s4;
					else
						state <= s3;
					end if;
					
					
					data_enable <= '1';		
					addressing_on <= '0';
					decode_on <= '0';
					instruction_size <= instruction_info(11 downto 8);
					tru_cpu <= instruction_info(7 downto 4);
					type_info <= instruction_info( 3 downto 0);
					state_machine_onehot <= "0000000000001000";

				when s4 =>
					if ((state_machine_onehot = "0000000000010000") and (memory_calculate_done = '1'))then
						state <= calculate_memory_pointer;
					else
						state <= s4;
					end if;

					PC <= std_logic_vector(unsigned(PC) + unsigned(instruction_size));
					state_machine_onehot <= "0000000000010000";
					memory_calculate_on <= '1';


				when calculate_memory_pointer =>
				
					if pointer_calculation_done = '1'  then
						state <= s5;
					end if;

					memory_calculate_on <= '0';

					case adr_type is 
						when 0 =>	
							if ((op_code = X"20") or (op_code = X"4c")) then
								effective_memory_pointer(23 downto 16) <=	PBR;
								effective_memory_pointer(15 downto 0)	<=	memory_pointer(15 downto 0);
							else
								effective_memory_pointer(23 downto 16) <= 	DBR; 
								effective_memory_pointer(15 downto 0)	<=	memory_pointer(15 downto 0);
							end if;
							
							pointer_calculation_done := '1';

						when 1 =>
							effective_memory_pointer <= (others => 'Z');
							pointer_calculation_done := '1';
							
						when 2 => 
							effective_memeory_pointer_temp(23 downto 16) 	:= 	DBR; 
							effective_memeory_pointer_temp(15 downto 0)		:=	memory_pointer(15 downto 0);
							effective_memory_pointer <= std_logic_vector(unsigned(effective_memeory_pointer_temp) + unsigned(X_REG));
							pointer_calculation_done := '1';
							
						when 3 =>
							effective_memeory_pointer_temp(23 downto 16) 	:= 	DBR; 
							effective_memeory_pointer_temp(15 downto 0)		:=	memory_pointer(15 downto 0);
							effective_memory_pointer <= std_logic_vector(unsigned(effective_memeory_pointer_temp) + unsigned(Y_REG));
							pointer_calculation_done := '1';
							
						when 4 => 
							effective_memory_pointer <= memory_pointer;
							pointer_calculation_done := '1';
							
						when 5 =>
							effective_memory_pointer <= std_logic_vector(unsigned(memory_pointer) + unsigned(X_REG));
							pointer_calculation_done := '1';
							
						when 6 =>
							effective_memory_pointer(23 downto 16) <=	PBR;
							effective_memory_pointer(15 downto 0)	<=	memory_pointer(15 downto 0);
							pointer_calculation_done := '1';
							
						when 7 =>
							effective_memory_pointer(23 downto 16) <=	PBR;
							effective_memory_pointer(15 downto 0)	<=	memory_pointer(15 downto 0) + X_REG;
							pointer_calculation_done := '1';
							
						when 8 =>
							effective_memory_pointer(23 downto 16) <= 	(others => '0');
							effective_memory_pointer(15 downto 0)  <=	DP + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 9 =>
							effective_memory_pointer(23 downto 16) <= 	(others => '0');
							effective_memory_pointer(15 downto 0)  <=	StackPointer + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 10=> 
							effective_memory_pointer(23 downto 16) <= 	(others => '0');
							effective_memory_pointer(15 downto 0)  <=	DP + X_REG  + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 11=>
							effective_memory_pointer(23 downto 16) <= 	(others => '0');
							effective_memory_pointer(15 downto 0)  <=	DP + Y_REG  + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 12=>
							effective_memory_pointer(23 downto 16) <= 	DBR; 
							effective_memory_pointer(15 downto 0)	<=	DP + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 13=>
							effective_memory_pointer(23 downto 16) <= 	(others => '0');
							effective_memory_pointer(15 downto 0)  <=	DP + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 14=>
							effective_memory_pointer(23 downto 16) <= 	DBR;
							effective_memory_pointer(15 downto 0)	<= 	StackPointer + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 15=>
							effective_memory_pointer(23 downto 16) <= 	DBR;
							effective_memory_pointer(15 downto 0)	<=	X_REG + DP + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 16=> 
							effective_memory_pointer(23 downto 16) <=	DBR;
							effective_memory_pointer(15 downto 0)	<=	DP + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 17=>
							effective_memory_pointer(23 downto 16) <=	(others => '0');
							effective_memory_pointer(15 downto 0)	<=	DP + memory_pointer(7 downto 0);
							pointer_calculation_done := '1';
							
						when 18=> 
							effective_memory_pointer <= (others => 'Z');
							pointer_calculation_done := '1';
							
						when 19=>
					--	These program counter relative operations are calculated in the 
					--	PC state of execution.
							effective_memory_pointer <= (others => 'Z');
							pointer_calculation_done := '1';
							
						when 20=> 
					--	These program counter relative operations are calculated in the 
					--	PC state of execution.
							effective_memory_pointer <= (others => 'Z');
							pointer_calculation_done := '1';
							
						when 21=>
					--	Stack Operations are handled in the stack state or where neccicary
							effective_memory_pointer <= X"00" & StackPointer;
							pointer_calculation_done := '1';
							
						when 22=> 
					--	Block operations are not implemented yet
							effective_memory_pointer <= (others => 'Z');
							pointer_calculation_done := '1';
							
						when 23 =>
							requested_values <= X"00" & memory_pointer;
							pointer_calculation_done := '1';
							
						when others =>
							effective_memory_pointer <= (others => 'Z');
							pointer_calculation_done := '1';
							
					end case;

				when s5 =>

					pointer_calculation_done := '0';
					state_machine_onehot <= "0000000000100000";
					
					if state_machine_onehot = "0000000000100000" then
				--	Go to fan out based on type info,
				--	if type info is not 0 - 8, then count it
				--	as a NOP
				--
						if type_info = X"0" then
							state <= sa;

						elsif type_info = X"1" then
							state <= sp;

						elsif type_info = X"2" then
							state <= sm;

						elsif type_info = X"3" then
							state <= sc;

						elsif type_info = X"4" then
							state <= sf;

						elsif type_info = X"5" then
							state <= ss;

						elsif type_info = X"6" then
							state <= sn;

						elsif type_info = X"7" then
							state <= se;

						elsif type_info = X"8" then
							state <= si;

				-- if state can not be defined treat it as a NOP
						else 
							state <= sn;	

						end if;
					end if;

				when sc => 

					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= sc;
					end if;


					state_machine_onehot <= "0000000001000000";

			--	
			--	Arithmatic State Start
			--
				when sa =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= sa;
					end if;


				--	ADC
					if op_code =	X"6D" or  
					op_code =	X"7D" or 
					op_code =	X"79" or 
					op_code =	X"6F" or 
					op_code =	X"7F" or 
					op_code =	X"17" or 
					op_code =	X"65" or 
					op_code =	X"63" or 
					op_code =	X"75" or 
					op_code =	X"72" or 
					op_code =	X"67" or 
					op_code =	X"73" or 
					op_code =	X"61" or 
					op_code =	X"71" or 
					op_code =	X"77" or 
					op_code =	X"69" then 

						math_temp := ('0' & requested_values(15 downto 0)) + A_REG +  ( zeros & C_FLAG);

						if ((math_temp = "00000000000000000" ) or (math_temp = "10000000000000000")) then
							Z <= '1';
							N <= math_temp (15);                        
							V <= math_temp (16);                        
							C_FLAG <= math_temp (16) xor (not math_temp(16));
							A_REG <= math_temp(15 downto 0);
							math_done <= '1';
						elsif math_temp /= "ZZZZZZZZZZZZZZZZZ" then
							Z <= '0';
							N <= math_temp (15);
							V <= math_temp (16);
							C_FLAG <= math_temp (16) xor (not math_temp(16));
							A_REG <= math_temp(15 downto 0);
							math_done <= '1';
						end if;


				--	AND
					elsif op_code = X"2D" or 
					op_code = X"3E" or
					op_code = X"39" or
					op_code = X"2F" or
					op_code = X"3F" or
					op_code = X"25" or
					op_code = X"23" or
					op_code = X"36" or
					op_code = X"32" or
					op_code = X"27" or
					op_code = X"33" or
					op_code = X"91" or
					op_code = X"31" or
					op_code = X"37" or
					op_code = X"29"	then 

						math_temp := '0' & ( A_REG and requested_values(15 downto 0));
						if math_temp = "00000000000000000" then
							Z <= '1';
							N <= math_temp(15); 
						else
							N <= math_temp(15);
							Z <= '0';
						end if;

						A_REG <= math_temp(15 downto 0 );
						math_done <= '1';

				--	ASL
					elsif
					op_code = X"0E" or 
					op_code = X"1E" or 
					op_code = X"06" or 
					op_code = X"16" then

						math_temp := requested_values(15 downto 0) &  '0';
						C_FLAG <= requested_values(15);
						store_back <= '1';
						if math_temp(15 downto 0) = "0000000000000000" then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;
						math_done <= '1';




					elsif op_code = X"0A" then

						math_temp := A_REG( 15 downto 0) & '0';
						C_FLAG <= A_REG(15);
						if math_temp(15 downto 0) = ("0000000000000000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;
						A_REG <= math_temp(15 downto 0);
						math_done <= '1';

				--	CMP
					elsif 
					op_code = X"CD" or  
					op_code = X"DD" or  
					op_code = X"D9" or  
					op_code = X"CF" or  
					op_code = X"DF" or  
					op_code = X"C5" or  
					op_code = X"C3" or  
					op_code = X"D5" or  
					op_code = X"D2" or  
					op_code = X"C7" or  
					op_code = X"D3" or  
					op_code = X"C1" or  
					op_code = X"D1" or  
					op_code = X"D7" or  
					op_code = X"C9" then

						math_temp := A_REG - ('0' & requested_values(15 downto 0));

						if (A_REG < requested_values) then
							C_FLAG <= '0';
						else
							C_FLAG <= '1';
						end if;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;
						math_done <= '1';

				--	CPX
					elsif 
					op_code = X"EC" or 
					op_code = X"E4" or 
					op_code = X"E0" then

						math_temp := X_REG - ('0' & requested_values(15 downto 0));

						if (X_REG < requested_values) then
							C_FLAG <= '0';
						else
							C_FLAG <= '1';
						end if;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;

						math_done <= '1';


				--	CPY
					elsif 
					op_code = X"CC" or 
					op_code = X"C4" or 
					op_code = X"C0" then

						math_temp := Y_REG - ('0' & requested_values(15 downto 0));

						if (Y_REG < requested_values) then
							C_FLAG <= '0';
						else
							C_FLAG <= '1';
						end if;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;
						math_done <= '1';


				--	DEX
					elsif 
					op_code = X"CA" then 

						math_temp := '0' & X_REG - 1;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;

						X_REG <= math_temp(15 downto 0);					
						math_done <= '1';

				--	DEY
					elsif 
					op_code = X"88" then 

						math_temp := '0' & Y_REG - 1;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;

						Y_REG <= math_temp(15 downto 0);					
						math_done <= '1';


				--	EOR
					elsif 
					op_code = X"4D" or 
					op_code = X"5D" or 
					op_code = X"59" or 
					op_code = X"4F" or 
					op_code = X"5F" or 
					op_code = X"5D" or 
					op_code = X"45" or 
					op_code = X"43" or 
					op_code = X"55" or 
					op_code = X"52" or 
					op_code = X"47" or 
					op_code = X"53" or 
					op_code = X"41" or 
					op_code = X"51" or 
					op_code = X"57" or 
					op_code = X"49" then 

						math_temp := '0' & (requested_values(15 downto 0) xor A_REG);

						if math_temp = ('0'&(X"0000")) then
							Z <= '1';
						else
							Z <= '0';
						end if;

						N <= math_temp(15);

						store_back <= '1';
						math_done <= '1';


				--	INX
					elsif 
					op_code = X"E8" then 

						math_temp := '0' & X_REG + 1;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15);
						else
							N <= math_temp(15);
							Z <= '0';
						end if;

						X_REG <= math_temp(15 downto 0);					
						math_done <= '1';


				--	INY
					elsif 
					op_code = X"C8" then

						math_temp := '0' & Y_REG + 1;

						if math_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= math_temp(15); 
						else
							N <= math_temp(15);
							Z <= '0';
						end if;

						Y_REG <= math_temp(15 downto 0);					
						math_done <= '1';



				--	LSR
					elsif 
					op_code = X"4A" then 

						math_temp := '0' & A_REG;

						N <= '0';
						C_FLAG <= A_REG(0);
						if math_temp = ('0' & X"0000") then
							Z <= '0';
						else
							Z <= '1';
						end if;

						A_REG <= math_temp (16 downto 1);
						math_done <= '1';

					elsif
					op_code = X"4E" or 
					op_code = X"5E" or 
					op_code = X"46" or 
					op_code = X"56" then

						math_temp := '0' & requested_values(15 downto 0);

						store_back <= '1';
						N <= '0';
						C_FLAG <= requested_values(0);
						if math_temp = ('0' & X"0000") then
							Z <= '0';
						else
							Z <= '1';
						end if;
						math_done <= '1';

				--	ORA
					elsif 
					op_code = X"0D" or 
					op_code = X"1D" or 
					op_code = X"19" or 
					op_code = X"0F" or 
					op_code = X"1F" or 
					op_code = X"05" or 
					op_code = X"03" or 
					op_code = X"15" or 
					op_code = X"12" or 
					op_code = X"07" or 
					op_code = X"13" or 
					op_code = X"01" or 
					op_code = X"11" or 
					op_code = X"17" or 
					op_code = X"09" then

						math_temp := '0' & (requested_values(15 downto 0) or A_REG);
						A_REG <= math_temp;

						if math_temp = ('0' & X"0000") then
							Z <= '1';
						else
							Z <= '0';
						end if;

						N <= math_temp(15);

						store_back <= '1';
						math_done <= '1';


				--	ROL
					elsif 
					op_code = X"2A" then 

						math_temp := A_REG & C_FLAG;
						C_FLAG <= A_REG (15);
						N <= math_temp(15);

						if math_temp(16 downto 1) = X"0000" then
							Z <= '1';
						else
							Z <= '0';
						end if;

						A_REG <= math_temp (15 downto 0);
						math_done <= '1';

					elsif
					op_code = X"2E" or 
					op_code = X"3E" or 
					op_code = X"26" or 
					op_code = X"36" then 

						math_temp := requested_values(15 downto 0) & C_FLAG;
						C_FLAG <= A_REG (15);
						N <= math_temp(15);
						store_back <= '1';

						if math_temp(16 downto 1) = (X"0000") then
							Z <= '1';
						else
							Z <= '0';
						end if;
						math_done <= '1';


				--	ROR
					elsif 
					op_code = X"6A" then

						math_temp := C_FLAG & A_REG;
						C_FLAG <= A_REG (0);
						N <= math_temp(15);

						if math_temp(16 downto 1) = (X"0000") then
							Z <= '1';
						else
							Z <= '0';
						end if;

						A_REG <= math_temp (16 downto 1);
						math_done <= '1';


					elsif
					op_code = X"6E" or 
					op_code = X"7E" or 
					op_code = X"66" or 
					op_code = X"76" then

						math_temp := C_FLAG & requested_values(15 downto 0) ;
						C_FLAG <= requested_values (0);
						N <= math_temp(15);
						store_back <= '1';

						if math_temp(16 downto 1) = (X"0000") then
							Z <= '1';
						else
							Z <= '0';
						end if;

						math_done <= '1';



					--	SBC
					elsif 
					op_code = X"ED" or 
					op_code = X"FD" or 
					op_code = X"F9" or 
					op_code = X"FF" or 
					op_code = X"E5" or 
					op_code = X"E3" or 
					op_code = X"F5" or 
					op_code = X"F2" or 
					op_code = X"E7" or 
					op_code = X"F3" or 
					op_code = X"E1" or 
					op_code = X"F1" or 
					op_code = X"F7" or 
					op_code = X"E9" then 

						math_temp :=  A_REG - ('0' & requested_values(15 downto 0)) - ( ('0' & zeros) & C_FLAG);

						if ((math_temp = ('0' & X"0000")) or (math_temp = "10000000000000000")) then
							Z <= '1';
							N <= math_temp (15);                        
							V <= math_temp (16);                        
							C_FLAG <= math_temp (16) xor (not math_temp(16));
						else
							Z <= '0';
							N <= math_temp (15);
							V <= math_temp (16);
							C_FLAG <= math_temp (16) xor (not math_temp(16));
						end if;
						A_REG <= math_temp(15 downto 0);

						math_done <= '1';

					end if;

					if (store_back = '1') and (math_done = '1') then
						write_back_value <= math_temp (15 downto 0);
						write_back_location <= effective_memory_pointer;
						state_machine_onehot <= "0000000001000000";
					elsif math_done = '1' then
						state_machine_onehot <= "0000000001000000";
					else 
						
						state_machine_onehot <= state_machine_onehot;
					end if;
				--
				--	END OF ARITHMATIC STATE
				--

				--
				--	START MEMORY MANIPULATION STATE
				--

				when sm =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= sm;
					end if;

					--	DEC
					if op_code = X"CE" or
					op_code= X"DE" or   
					op_code= X"C6" or   
					op_code= X"D6" then

						mem_temp := '0' & requested_values(15 downto 0) - 1 ;

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;
						write_back_value <= mem_temp(15 downto 0);
						memory_done <= '1';		
						store_back <= '1';						


					elsif op_code = X"3A" then

						mem_temp := '0' & A_REG - 1 ;

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;
						A_REG <= mem_temp(15 downto 0);
						memory_done <= '1';		


					--	INC
					elsif op_code= X"1A" then

						mem_temp := '0' & A_REG + 1 ;

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;
						A_REG <= mem_temp(15 downto 0);
						memory_done <= '1';		


					elsif op_code = X"EE" or 
					op_code= X"FE" or 
					op_code= X"E6" or 
					op_code= X"F6" then

						mem_temp := '0' & requested_values(15 downto 0) + 1 ;

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;
						write_back_value <= mem_temp(15 downto 0);
						memory_done <= '1';		
						store_back <= '1';						

					--	LDA
					elsif op_code = X"AD" or 
					op_code= X"BD" or 
					op_code = X"B9" or 
					op_code = X"AF" or 
					op_code = X"BF" or 
					op_code = X"A5" or 
					op_code = X"A3" or 
					op_code = X"B5" or 
					op_code = X"B2" or 
					op_code = X"A7" or 
					op_code = X"B3" or 
					op_code = X"A1" or 
					op_code = X"B1" or 
					op_code = X"B7" then

						mem_temp := '0' & requested_values(15 downto 0);
						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;

						A_REG <= mem_temp(15 downto 0);

						memory_done <= '1';			

					elsif op_code = X"A9" then

						mem_temp := '0' & requested_values(15 downto 0);

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;

						A_REG <= mem_temp(15 downto 0);

						memory_done <= '1';			

					--	LDX
					elsif op_code = X"AE" or 
					op_code= X"BE" or 
					op_code= X"A6" or 
					op_code= X"B6" or 
					op_code= X"A2" then

						mem_temp := '0' & requested_values(15 downto 0);

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;

						X_REG <= mem_temp(15 downto 0);

						memory_done <= '1';			

					--	LDY
					elsif op_code = X"AC" or 
					op_code= X"BC" or   
					op_code= X"A4" or   
					op_code= X"B4" or   
					op_code= X"A0" then

						mem_temp := '0' & requested_values(15 downto 0);

						if mem_temp (15 downto 0) = (X"0000") then
							Z <= '1';
							N <= mem_temp(15);
						else
							N <= mem_temp(15);
							Z <= '0';
						end if;

						Y_REG <= mem_temp(15 downto 0);

						memory_done <= '1';			

					--	STA
					elsif op_code = X"8D" or 
					op_code= X"9D" or  
					op_code= X"8F" or  
					op_code= X"9F" or  
					op_code= X"85" or  
					op_code= X"83" or  
					op_code= X"95" or  
					op_code= X"92" or  
					op_code= X"87" or  
					op_code= X"93" or  
					op_code= X"81" or  
					op_code= X"91" or  
					op_code= X"97" then

						mem_temp := '0' & A_REG;

						write_back_value <= mem_temp(15 downto 0);

						store_back <= '1';

						memory_done <= '1';


					--	STX
					elsif op_code = X"8E" or 
					op_code= X"86" or 
					op_code= X"96" then

						mem_temp := '0' & X_REG;

						write_back_value <= mem_temp(15 downto 0);

						store_back <= '1';

						memory_done <= '1';



					--	STY
					elsif op_code = X"8C" or 
					op_code= X"84" or
					op_code= X"94" then 

						mem_temp :='0' & Y_REG;

						write_back_value <= mem_temp(15 downto 0);

						store_back <= '1';

						memory_done <= '1';


					end if;

					if (memory_done = '1') and (store_back = '1') then
						state_machine_onehot <= "0000000001000000";
						write_back_location <= effective_memory_pointer;
					elsif (memory_done = '1') then
						state_machine_onehot <= "0000000001000000";
						store_back <= '0';
					else
						state_machine_onehot <= state_machine_onehot;
					end if;


				--
				--	END MEMORY MANIPULATION STATE
				--

				--
				--	START PC MANIPULATION STATE
				--
				when sp =>

					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= sp;
					end if;

					--	BCC
					if op_code = X"90" then

						if C_FLAG = '0' then 
							PC <= PC + std_logic_vector((resize(signed(memory_pointer(7 downto 0)), 16)));
						else
							PC <= PC;
						end if;

						pc_done <= '1';

					--	BEQ
					elsif op_code = X"F0" then

						if Z = '1' then 
							PC <= PC + std_logic_vector((resize(signed(memory_pointer(7 downto 0)), 16)));
						else
							PC <= PC;
						end if;

						pc_done <= '1';

					--	BMI
					elsif op_code = X"30" then

						if N = '1' then 
							PC <= PC + std_logic_vector(resize(signed(memory_pointer(7 downto 0)), 16));
						else
							PC <= PC;
						end if;

						pc_done <= '1';

					--	BNE
					elsif op_code = X"D0" then

						if Z = '0' then 
							PC <= PC + std_logic_vector(resize(signed(memory_pointer(7 downto 0)), 16));
						else
							PC <= PC;
						end if;

						pc_done <= '1';

					--	BPL
					elsif op_code = X"10" then

						if N = '0' then 
							PC <= PC + std_logic_vector(resize(signed(memory_pointer(7 downto 0)), 16));
						else
							PC <= PC;
						end if;

						pc_done <= '1';

					--	BVC
					elsif op_code = X"50" then

						if V = '0' then 
							PC <= PC + std_logic_vector(resize(signed(memory_pointer(7 downto 0)), 16));
						else
							PC <= PC;
						end if;

						pc_done <= '1';


					--	BVS
					elsif op_code = X"70" then


						if V = '1' then 
							PC <= PC + std_logic_vector(resize(signed(memory_pointer(7 downto 0)), 16));
						else
							PC <= PC;
						end if;

						pc_done <= '1';


					--	JMP
					elsif 
					op_code = X"4C" then

						PC <= effective_memory_pointer;
						pc_done <= '1';

					elsif
					op_code = X"5C"	then

						PC <= requested_values(23 downto 0);
						pc_done <= '1';

					elsif 
					op_code = X"6C" or 
					op_code = X"7C" then

						PC <=  requested_values(23 downto 0);
						pc_done <= '1';

					--	JSR
					elsif op_code = X"20" or
					op_code = X"FC" then

						write_back_value <= ProgramCntr;
						write_back_bank <= PBR;
						PC <= requested_values(23 downto 0);
						push_to_stack <= '1';
						pc_done <= '1';


					--	RTS
					elsif op_code = X"60" then

						ProgramCntr <= requested_values(15 downto 0);
						StackPointer <= StackPointer - 2;
						pc_done <= '1';


					end if;

					if (pc_done = '1') then
						state_machine_onehot <= "0000000001000000";
					else
						state_machine_onehot <= state_machine_onehot;
					end if;


				--
				--	END PC MANIPULATION STATE
				--

				--
				--	START FLAGC MANIPULATION STATE
				--
				when sf =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= sf;
					end if;


					--	BIT
					if op_code = X"2C" or 
					op_code = X"3C" or 
					op_code = X"24" or 
					op_code = X"34" then

						flag_temp := '0' & (A_REG and requested_values(15 downto 0));

						if flag_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= flag_temp(15);
							V <= flag_temp(14);
						else
							V <= flag_temp(14);
							N <= flag_temp(15);
							Z <= '0';
						end if;
						flag_done <= '1';

					elsif op_code = X"89" then

						flag_temp := '0' & A_REG and requested_values(15 downto 0);
						if flag_temp(15 downto 0) = (X"0000") then
							Z <= '1';
						else
							Z <= '0';
						end if;
						flag_done <= '1';

				--	CLC
					elsif op_code = X"18" then

						C_FLAG <= '0';
						flag_done <= '1';

				--	CLD
					elsif op_code = X"D8" then

						D_FLAG <=  '0';
						flag_done <= '1';

				--	CLI
					elsif op_code = X"58" then

						I <= '0';
						flag_done <= '1';

				--	CLV
					elsif op_code = X"B8" then

						V <= '0';
						flag_done <= '1';

				--	SEC
					elsif op_code = X"38" then

						C_FLAG <= '1';
						flag_done <= '1';

				--	SED
					elsif op_code = X"F8" then

						D_FLAG <=  '0';
						flag_done <= '1';

				--	SEI
					elsif op_code = X"78" then

						I <= '1';
						flag_done <= '1';

					end if;

					if flag_done = '1' then
						state_machine_onehot <= "0000000001000000";
					else
						state_machine_onehot <= state_machine_onehot;
					end if;
			--
			--	END FLAG MANIPULATION STATE
			--
			--
			--	STACK MANIPULATION STATE
			--

				when ss =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= ss;
					end if;

				--	PHA
					if op_code = X"48" then

						StackPointer <= StackPointer + 2;
						push_to_stack <= '1';
						write_back_value <= A_REG;
						stack_done <= '1';

				--	PHP
					elsif op_code = X"08" then

						StackPointer <= StackPointer + 1;
						push_to_stack <= '1';
						write_back_value <= X"00" & P;
						stack_done <= '1';

				--	PLA
					elsif op_code = X"68" then

						StackPointer <= StackPointer - 2;
						stack_temp := '0' & requested_values(15 downto 0);
						if stack_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= stack_temp(15);
						else
							N <= stack_temp(15);
							Z <= '0';
						end if;
						A_REG <= stack_temp(15 downto 0);
						stack_done <= '1';

				--	PLP
					elsif op_code = X"28" then

						StackPointer <= StackPointer - 1;
						stack_temp := '0' & requested_values(15 downto 0);
						if stack_temp(15 downto 0) = (X"0000") then
							Z <= '1';
							N <= stack_temp(15);
						else
							N <= stack_temp(15);
							Z <= '0';
						end if;
						P <= stack_temp(7 downto 0);
						stack_done <= '1';

					end if;


					if (stack_done = '1') and (store_back = '1') then
						write_back_location <= effective_memory_pointer;
						state_machine_onehot <= "0000000001000000";
					elsif (stack_done = '1') then
						state_machine_onehot <= "0000000001000000";
					else
						state_machine_onehot <= state_machine_onehot;
					end if;

			--
			--	 END STACK MANIPULATION STATE
			--
			--
			--	 START NOP STATE
			--
				when sn =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= sn;
					end if;

					state_machine_onehot <= "0000000001000000";
			--
			--	 END NOP STATE
			--
			--
			--	 START EXCHANGE STATE
			--
				when se =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= se;
					end if;

				--	TAX
					if op_code = X"AA" then

						xfr_temp := '0' & A_REG;
						if xfr_temp(15 downto 0)  = (X"0000") then
							Z <= '1';
							N <= xfr_temp(15);
						else
							N <= xfr_temp(15);
							Z <= '0';
						end if;
						X_REG <= xfr_temp(15 downto 0);
						exchange_done <= '1';

				--	TAY
					elsif op_code = X"AB" then
						xfr_temp := '0' & A_REG;
						if xfr_temp(15 downto 0)  = (X"0000") then
							Z <= '1';
							N <= xfr_temp(15);
						else
							N <= xfr_temp(15);
							Z <= '0';
						end if;
						Y_REG <= xfr_temp(15 downto 0);
						exchange_done <= '1';

				--	TYA
					elsif op_code = X"98" then 
						xfr_temp := '0' & Y_REG;
						if xfr_temp(15 downto 0)  = (X"0000") then
							Z <= '1';
							N <= xfr_temp(15);
						else
							N <= xfr_temp(15);
							Z <= '0';
						end if;
						A_REG <= xfr_temp(15 downto 0);
						exchange_done <= '1';

				--	TSX
					elsif op_code = X"BA" then
						xfr_temp := '0' & StackPointer;
						if xfr_temp(15 downto 0)  = (X"0000") then
							Z <= '1';
							N <= xfr_temp(15);
						else
							N <= xfr_temp(15);
							Z <= '0';
						end if;
						X_REG <= xfr_temp(15 downto 0);
						exchange_done <= '1';

				--	TXA
					elsif 
					op_code = X"8A" then
						xfr_temp := '0' & X_REG;
						if xfr_temp(15 downto 0)  = (X"0000") then
							Z <= '1';
							N <= xfr_temp(15);
						else
							N <= xfr_temp(15);
							Z <= '0';
						end if;
						A_REG <= xfr_temp(15 downto 0);
						exchange_done <= '1';

				--	TXS
					elsif 
					op_code = X"9A" then 
						xfr_temp := '0' & X_REG;
						StackPointer <= xfr_temp(15 downto 0);
						exchange_done <= '1';

					end if;


					if (exchange_done = '1') then
						state_machine_onehot <= "0000000001000000";
					else
						state_machine_onehot <= state_machine_onehot;
					end if;
		--
		--	 END EXCHANGE STATE
		--

		--
		--	 START INTERUPT STATE
		--
				when si =>
					if state_machine_onehot = "0000000001000000" then
						state <= s6;
					else
						state <= si;
					end if;

			--	RTI
					if op_code = X"40" then
						ProgramCntr <=	requested_values(23 downto 8);
						P	<=	requested_values(7 downto 0);
					end if;

					state_machine_onehot <= "0000000001000000";
		--
		--	 END INTRRUPT STATE
		--
				when s6 =>
					if (state_machine_onehot = "0000000010000000") and (ready_up = '1') then
						state <= s0;
					else
						state <= state;
					end if;

					math_done <= '0';
					memory_done <= '0';
					pc_done <= '0';
					flag_done <= '0';
					stack_done <= '0';
					exchange_done <= '0';


					if (store_back = '1') then
						READ_OUT <= write_back_value;
						ADDRESS_OUT <= write_back_location;
						store_back <= '0';
						state_machine_onehot <= "0000000010000000";
					elsif (push_to_stack = '1') then
						read_out <= write_back_value;
						read_out_bank <= write_back_bank;
						address_out <= X"00" & StackPointer;
						push_to_stack <= '0';
						state_machine_onehot <= "0000000010000000";
					else
						state_machine_onehot <= "0000000010000000";
					end if;


				when others =>

					state_machine_onehot <= "0000000000000010";


			end case;
		end if;
	end process;


--
--	This process will look at the opcode
--		and determine the addressing mode of 
--		the specific instruction being requested 
--		and then pass it onto the adr_type vector.
--
	Addressing_Mode:
	process (addressing_on) is

	begin

		addressing_done <= '0';

		if (addressing_on = '1') then
		--	Refer to 65000 Programmers Manual for explanation
		--		of addressing modes.
		--		
		--		Symbol Addressing Mode Symbol Addressing Mode
		--		0  ->	a		absolute
		--		1  ->	A_REG		accumulator
		--		2  ->	a,x		absolute indexed with X
		--		3  ->	a,y		absolute indexed with Y_REG
		--		4  ->	al		absolute long
		--		5  ->	al,x	absolute long indexed
		--		6  ->	(a)		absolute indirect
		--		7  ->	(a,x)	absolute indexed indirect
		--		8  ->	d		direct
		--		9  ->	d,s		stack relative
		--		10 ->	d,x		direct indexed with x 
		--		11 ->	d,y		direct indexed with y
		--		12 ->	(d)		direct indirect
		--		13 ->	[d]		direct indirect long
		--      14 ->	(d,s),y	stack relative indirect indexed
		--		15 ->	(d,x)	direct indexed indirect
		--		16 ->	(d),y	direct indirect indexed
		--		17 ->	[d].y	direct indirect long indexed
		--		18 ->	i		implied
		--		19 ->	r		program counter relative
		--		20 ->	rl		program counter relative long
		--		21 ->	s		stack
		--		22 ->	xyc		block move
		--		23 ->	#		immediate
		--
		--
			case op_code is

				when X"6d" | X"2d" | X"0e" | X"2c" | X"cd" | X"ec" | X"cc" | X"ce" | X"4d" | X"ee" | X"4c" | X"20" | X"ad" | X"ae" | X"ac" | X"4e" | X"0d" | X"2e" | X"6e" | X"ed" | X"8d" | X"8e" | X"8c" | X"9c" | X"1c" | X"0c"  =>
					adr_type <= 0;

				when X"0a" | X"3A" | X"1a" | X"4a" | X"2a" | X"6a" | X"3b" | X"ba" | X"8a" | X"9a" | X"9b" | X"98" | X"bb" | X"cb" | X"42" | X"eb" | X"fb"  =>
					adr_type <= 1;

				when X"7d" | X"3e" | X"1e" | X"3c" | X"dd" | X"de" | X"5d" | X"fe" | X"bd" | X"bc" | X"5e" | X"1d" | X"7e" | X"fd" | X"9d" | X"9e" =>
					adr_type <= 2;

				when X"6f" | X"2f" | X"cf" | X"4f" | X"5c" | X"22" | X"af" | X"0f" | X"8f" =>
					adr_type <= 3;

				when X"79" | X"39" | X"d9" | X"59" | X"b9" | X"be" | X"19" | X"f9" =>									
					adr_type <= 4;

				when X"7f" | X"3f" | X"df" | X"5f" | X"bf" | X"1f" | X"ff" | X"9f" =>									
					adr_type <= 5;

				when X"dc" | X"6c" =>					
					adr_type <= 6;

				when X"7c" | X"fc" =>					
					adr_type <= 7;

				when X"65" | X"25" | X"06" | X"24" | X"c5" | X"e4" | X"c4" | X"c6" | X"45" | X"e6" | X"a5" | X"a6" | X"a4" | X"46" | X"05" | X"26" | X"66" | X"e5" | X"85" | X"86" | X"84" | X"64" | X"14" | X"04" =>
					adr_type <= 8;

				when X"63" | X"23" | X"c3" | X"43" | X"a3" | X"03" | X"e3" | X"83" =>
					adr_type <= 9;

				when X"75" | X"36" | X"16" | X"34" | X"d5" | X"d6" | X"55" | X"f6" | X"b5" | X"b4" | X"56" | X"15" | X"76" | X"f5" | X"95" | X"94" | X"74" =>
					adr_type <= 10;

				when X"b6" | X"96" =>
					adr_type <= 11;

				when X"72" | X"32" | X"d2" | X"52" | X"b2" | X"12" | X"f2" | X"92" =>
					adr_type <= 12;

				when X"67" | X"27" | X"c7" | X"47" | X"a7" | X"07" | X"e7" | X"87" =>
					adr_type <= 13;

				when X"73" | X"33" | X"d3" | X"53" | X"b3" | X"13" | X"f3" | X"93" =>
					adr_type <= 14;

				when X"61" | X"c1" | X"41" | X"a1" | X"01" | X"e1" | X"81" =>
					adr_type <= 15;

				when X"71" | X"31" | X"d1" | X"51" | X"b1" | X"11" | X"f1" | X"91" =>
					adr_type <= 16;

				when X"77" | X"37" | X"d7" | X"57" | X"b7" | X"17" | X"f7" | X"97" =>
					adr_type <= 17;

				when X"18" | X"d8" | X"58" | X"b8" | X"ca" | X"88" | X"e8" | X"c8" | X"ea" | X"38" | X"f8" | X"78" | X"db" | X"aa" | X"5b" | X"1b" | X"7b" =>
					adr_type <= 18;

				when X"b0" | X"f0" | X"90" | X"d0" | X"10" | X"80" | X"50" | X"70" =>
					adr_type <= 19;

				when X"82" =>
					adr_type <= 20;

				when X"00" | X"02" | X"f4" | X"d4" | X"62" | X"48" | X"8b" | X"0b" | X"4b" | X"08" | X"da" | X"5a" | X"68" | X"ab" | X"2b" | X"28" | X"fa" | X"7a" | X"40" | X"6b" | X"60" =>
					adr_type <= 21;

				when X"54" | X"44" =>
					adr_type <= 22;

				when X"69" | X"29" | X"89" | X"c9" | X"e0" | X"c0" | X"49" | X"a9" | X"a2" | X"a0" | X"09" | X"c2" | X"e9" | X"e2" =>
					adr_type <= 23;

				when others =>
					adr_type <= 0;

			end case;

			addressing_done <= '1';
		end if;

	end process;


--
--	This process reverses the byte order
--	of instruction arguments so that 
--	a memory pointer or argument can
--	be precisely used
--
	memory_pointer_calculation:
	process (memory_calculate_on) is

	begin

		memory_calculate_done <= '0';

		if memory_calculate_on = '1' then

			case instruction_size is

				when X"2" =>
					memory_pointer <= X"0000" & chunk_pull (23 downto 16);

				when X"3" =>
					memory_pointer <= X"00" & chunk_pull(15 downto 8) & chunk_pull (23 downto 16);

				when X"4" =>
					memory_pointer <= chunk_pull (7 downto 0) & chunk_pull(15 downto 8) & chunk_pull (23 downto 16);

				when others =>
					memory_pointer <= (others => '0');

			end case;
			memory_calculate_done <= '1';

		end if;

	end process;


--
--	This  process will decode the OPcode byte.
--	It will then assign instruction_info all relevent data. 
--
	opcode_info: 
	process (decode_on) is 

	begin


		decode_done <= '0';

		if reset = '1' then

			instruction_info <= (others => '0');-- clear instruction info

		elsif (decode_on = '1') then 
		--
		--	
		--	intstruction_info syntax is
		--		bytes + cycles + type 
		--
		--	Flags (on reset) : 	
		--				N V M X D I Z C_FLAG/E	   
		--		   P =  * * 1 1 0 1 * */1		
		--		   * = Not Initialized		
		--			STP and WAI instructions are cleared.
		--	Type Table:
		--		0 -> Arithmatic
		--		1 -> PC 
		--		2 -> Memory
		--		3 -> Coprocessor 
		--		4 -> Flag
		--		5 -> Stack
		--		6 -> NOP (and non used)
		--		7 -> Exchange
		--		8 -> Interrupt
		--
		--	
		--		
		--		


			case op_code is

			--
			--	BRK (break)
			--	pc+2 onto stack, processor status onto stack	
			--	Also set  I flag = 1
			--
			--		!!!!!!!!!!!!! TODO: Implemented as a NOP for now due to issues with interrupts
			--			!!!!!!!!!!!!!!!!!!!!!!!!!!!  X"270" is now X"126"
				when X"00"	=> 
					instruction_info <= X"126";

			--	ADC
			--	The following are Add memory to accumulator with cary
			--		A_REG + M + C_FLAG -> A_REG, C_FLAG
			--
				when X"69" =>
					instruction_info <= X"220";

				when X"65" =>
					instruction_info <= X"230";

				when X"75" =>
					instruction_info <= X"240";

				when X"6D" =>
					instruction_info <= X"340";

				when X"7D" =>
					instruction_info <= X"340";

				when X"79" =>
					instruction_info <= X"340";

				when X"61" =>
					instruction_info <= X"260";

				when X"71" =>
					instruction_info <= X"250";

			--	AND
			--	The follwing are logical AND's with accumulator
			--		A_REG and M -> A_REG
			--
			--

				when X"29" =>
					instruction_info <= X"220";

				when X"25" =>
					instruction_info <= X"230";

				when X"35" =>
					instruction_info <= X"240";

				when X"2D" =>
					instruction_info <= X"340";

				when X"3D" =>
					instruction_info <= X"340";

				when X"39" =>
					instruction_info <= X"340";

				when X"21" =>
					instruction_info <= X"260";

				when X"31" =>
					instruction_info <= X"250";

			--
			--	The following are ASL
			--		left shift by one
			--			memory or accumulator
			--
				when X"0A" =>
					instruction_info <= X"120";

				when X"06" =>
					instruction_info <= X"250";

				when X"16" =>
					instruction_info <= X"260";

				when X"0E" =>
					instruction_info <= X"360";

				when X"1E" =>
					instruction_info <= X"370";

			--	BCC
			--	Branch on carry clear
			--		when carry flag = 0, branch
			--		* + 1 cycle if branch happens
				when X"90" =>
					instruction_info <= X"221";

			--	BEQ
			--	branch on zero flag set
			--		* + 1 cycle if branch happens	
				when X"F0" =>
					instruction_info <= X"221";

			--	BIT
			--	Accumulator AND'd with memory,
			--	bit 7 of memory goes to Negative flag
			--	bit 6 of memoyr goes to overflow flag
			--		If A_REG and M = 0 then Z = 1 , else 0
				when X"24" =>
					instruction_info <= X"234";
				when X"2C" =>
					instruction_info <= X"344";

			--	BMI
			--	Branch On Negative Flag Set
			--	* + 1 Cycle If Can Branch
				when X"30" =>
					instruction_info <= X"221";

			--	BNE
			--	Branch on zero flag not set
			-- 	* + 1 cycle if can do
			--
				when X"D0" =>
					instruction_info <= X"221";

			-- 	BPL
			--	Brnach when N flag not set.
			--	* + 1 cycle if can do
			--
				when X"10" =>
					instruction_info <= X"221";

			--	BVC 
			--	Branch on V flag = 0
			--	* +1 cycle if can do
				when X"50" =>
					instruction_info <= X"221";

			--	BVS
			--	Branch when V flag set
			--	* + 1 cycle if can do
				when X"70" =>
					instruction_info <= X"221";

			--	CLC
			--	Clear the carry flag
			--
				when X"18" =>
					instruction_info <= X"124";

			--	CLD
			-- 	Clear the decimal flag
			--	
				when X"D8" =>
					instruction_info <= X"124";

			--	CLI
			-- 	Clear interupt bit
			--
				when X"58" =>
					instruction_info <= X"124";

			--	CLV
			--	Clear the overflow flag
			--
				when X"B8" =>
					instruction_info <= X"124";

			--	CMP
			--	Compar memory and accumulator
			--		Set N, Z, or C_FLAG flag accordingly
			--		A_REG - M
			--
				when X"c9" =>
					instruction_info <= X"220";

				when X"c5" =>
					instruction_info <= X"230";

				when X"D5" =>
					instruction_info <= X"240";

				when X"DD" =>
					instruction_info <= X"340";

				when X"d9" =>
					instruction_info <= X"340";

				when X"c1" =>
					instruction_info <= X"260";

				when X"d1" =>
					instruction_info <= X"250";

			--	CPX
			--	Compary memory and X reg
			--	 X - M and set N, Z, C_FLAG flags as needed
			--
				when X"E0" =>
					instruction_info <= X"220";

				when X"E4" =>
					instruction_info <= X"230";

				when X"EC" =>
					instruction_info <= X"340";

			--	CPY
			--	Compary memory and Y_REG reg
			--	Y_REG - M
			--	Set N, Z, and C_FLAG flags as needed.
			--
				when X"C0" =>
					instruction_info <= X"220";

				when X"C4" =>
					instruction_info <= X"230";

				when X"cc" =>
					instruction_info <= X"340";

			--	DEC
			--	Decrimeent memory by 1
			--	M - 1 -> M
			--	Use N & Z flags
				when X"C6" =>
					instruction_info <= X"252";

				when X"D6" =>
					instruction_info <= X"262";

				when X"ce" =>
					instruction_info <= X"362";

				when X"de" =>
					instruction_info <= X"372";

			--	DEX
			-- 	Decriment X reg by 1
			-- 	X - 1 -> X
			-- 	use N & Z  flags
				when X"CA" =>
					instruction_info <= X"120";

			--	DEY
			--	Decriment Y_REG reg by 1
			--	Y_REG - 1 -> Y_REG
			--	N & Z flags
			--
				when X"88" =>
					instruction_info <= X"120";

			--	EOR
			--	Acc XOR Mem -> Acc
			-- 	N and Z flags
			--
				when X"49" =>
					instruction_info <= X"220";

				when X"45" =>
					instruction_info <= X"230";

				when X"55" =>
					instruction_info <= X"240";

				when X"4d" =>
					instruction_info <= X"340";

				when X"5d" =>
					instruction_info <= X"340";

				when X"59" =>
					instruction_info <= X"340";

				when X"41" =>
					instruction_info <= X"260";

				when X"51" =>
					instruction_info <= X"250";

			--	INC
			--	Incriment memory by one
			--	M + 1 -> M
			--	N & Z flags
			--
				when X"E6" =>
					instruction_info <= X"252";

				when X"F6" =>
					instruction_info <= X"262";

				when X"ee" =>
					instruction_info <= X"362";

				when X"fe" =>
					instruction_info <= X"372";

			--	INX
			--	Incriment X by one
			--	X + 1 -> X
			--	N & Z flags
			--

				when X"e8" =>
					instruction_info <= X"120";

			--	INY
			--	Incriment Y_REG by one
			--	Y_REG + 1 -> Y_REG
			--	N & Z flags
			--
				when X"c8" =>
					instruction_info <= X"120";
			--
			--
			--		JMP
			--		JUMP INSTRUCTIONS
			--=======================================================================
			--	JMP
			--	Jump to location
			--	PC + 1 -> PCL
			--	PC + 2 -> PCH	

			--JMP absolute
			--take contents of memory location
			--1 byte from opcode and store into 
			--PC LOW, then take the very next byte
			--and store into PC HIGH
			--	REVERSE BYTE ORDER AND MAKE NEW PC
				when X"4c" =>
					instruction_info <= X"331";

			--JMP indirect
			-- starts out the same as above, but
			-- instead of getting the opcode at the new PC,
			-- a new PC is again fetched in the same way.
			-- making this a jump to a jump.
				when X"6c" =>	
					instruction_info <= X"351";
			--=======================================================================
			--
			--
			--
			--				
			--	JSR
			--	Jump to subroutine
			--	PC + 2 -> stack
			--	PC + 1 -> PCL
			--	PC + 2 -> PCH
			--
				when X"20" =>
					instruction_info <= X"361";

			--	LDA
			--	Load accumulator with memory
			--	M -> A_REG
			--	N & Z flags

				when X"a9" =>
					instruction_info <= X"222";

				when X"a5" =>
					instruction_info <= X"232";

				when X"b5" =>
					instruction_info <= X"242";

				when X"ad" =>
					instruction_info <= X"342";

				when X"bd" =>
					instruction_info <= X"342";

				when X"b9" =>
					instruction_info <= X"342";

				when X"a1" =>
					instruction_info <= X"262";

				when X"b1" =>
					instruction_info <= X"252";


			--	LDX
			--	Load X with memory
			--	M -> X
			--	N & Z flags
			--
				when X"a2" =>
					instruction_info <= X"222";

				when X"a6" =>
					instruction_info <= X"232";

				when X"b6" =>
					instruction_info <= X"242";

				when X"ae" =>
					instruction_info <= X"342";

				when X"be" =>
					instruction_info <= X"342";

			--	LDY
			-- 	Load Y_REG with memory
			--	M -> Y_REG
			--	N & Z Flags
			--
				when X"a0" =>
					instruction_info <= X"222";

				when X"a4" =>
					instruction_info <= X"232";

				when X"b4" =>
					instruction_info <= X"242";

				when X"ac" =>
					instruction_info <= X"342";

				when X"bc" =>
					instruction_info <= X"342";

			--	LSR
			--	Right shift one bit
			--	0 -> [bits] -> C_FLAG
			--	C_FLAG & Z flag, N flag zerod
			--
				when X"4a" =>
					instruction_info <= X"120";

				when X"46" =>
					instruction_info <= X"250";

				when X"56" =>
					instruction_info <= X"260";

				when X"4e" =>
					instruction_info <= X"360";

				when X"5e" =>
					instruction_info <= X"370";

			--	NOP
			--	No operation
			--
				when X"ea" =>
					instruction_info <= X"126";

			--	ORA
			--	Or with accumulator
			--	A_REG (or) M -> A_REG
			--	N & Z flags
			--	
				when X"09" =>
					instruction_info <= X"220";

				when X"05" =>
					instruction_info <= X"230";

				when X"15" =>
					instruction_info <= X"240";

				when X"0d" =>
					instruction_info <= X"340";

				when X"1d" =>
					instruction_info <= X"340";

				when X"19" =>
					instruction_info <= X"340";

				when X"01" =>
					instruction_info <= X"260";

				when X"11" =>
					instruction_info <= X"250";

			--	PHA
			--	Push accumuator to stack
			--	A_REG -> STACK
			--	NO FLAGS
				when X"48" =>
					instruction_info <= X"135";

			--	PHP
			--	Push processor status on stack
			--	P -> STACK
				when X"08" =>
					instruction_info <= X"135";

			--	PLA
			--	Pull accumulator from stack
			--	STACK -> A_REG
			--	N & Z flags
			--
				when X"68" =>
					instruction_info <= X"145";

			--	PLP
			--	Pull processor status from stack
			--	STACK -> P
			--	ALL FLAGS CAN CHANGE
				when X"28" =>
					instruction_info <= X"145";

			--	ROL
			--	Rotate one bit left
			--	[bit 7] -> C_FLAG FLAG
			--	[ <- bits 6 - 0] [C_FLAG FLAG (becomes 0 bit)]
			--	N & Z & C_FLAG FLAGS 
			--
				when X"2a" =>
					instruction_info <= X"120";

				when X"26" =>
					instruction_info <= X"250";

				when X"36" =>
					instruction_info <= X"260";

				when X"2e" =>
					instruction_info <= X"360";

				when X"3e" =>
					instruction_info <= X"270";

			--	ROR
			--	Rotate right one
			--	[C_FLAG FLAG -> bit 7] [bits 7 - 1 ] [bit 0 becomes C_FLAG flag]
			--	N & Z & C_FLAG
			--
				when X"6a" =>
					instruction_info <= X"120";

				when X"66" =>
					instruction_info <= X"250";

				when X"76" =>
					instruction_info <= X"260";

				when X"6e" =>
					instruction_info <= X"360";

				when X"7e" =>
					instruction_info <= X"370";

			--	RTI
			--	Return from Interrupt
			--	STACK -> P
			--	STACK -> PC
			--	FLAGS FROM STACK
			--
				when X"40" =>
					instruction_info <= X"168";

			--	RTS
			-- 	Reutrn from subroutine
			--	STACK -> PC
			--	PC + 1 -> PC
			--	NO FLAGS
			--
				when X"60" =>
					instruction_info <= X"161";

			--	SBC
			--	Subtract memory from accumulator w/ borrow
			--	A_REG - M - (not) C_FLAG -> Accumulator
			--	N & Z & C_FLAG & V Flags
			--
				when X"e9" =>
					instruction_info <= X"220";

				when X"e5" =>
					instruction_info <= X"230";

				when X"f5" =>
					instruction_info <= X"240";

				when X"ed" =>
					instruction_info <= X"340";

				when X"fd" =>
					instruction_info <= X"340";

				when X"f9" =>
					instruction_info <= X"340";

				when X"e1" =>
					instruction_info <= X"260";

				when X"f1" =>
					instruction_info <= X"250";

			--	SEC
			--	Set carry flag
			--	1 -> C_FLAG
			--	C_FLAG Flag
			--
				when X"38" =>
					instruction_info <= X"124";

			--	SED
			--	Set decimal flag
			--	1 -> D
			--	D flag
			--
				when X"f8" =>
					instruction_info <= X"124";

			--	SEI
			--	Set interrupt disable flag
			--	1 -> I
			--	I FLAG
				when X"78" =>
					instruction_info <= X"124";

			--	STA
			--	Store accumulator in memory
			--	A_REG -> M
			--	no flags
			--
				when X"85" =>
					instruction_info <= X"232";

				when X"95" =>
					instruction_info <= X"242";

				when X"8d" =>
					instruction_info <= X"342";

				when X"9d" =>
					instruction_info <= X"352";

				when X"99" =>
					instruction_info <= X"352";

				when X"81" =>
					instruction_info <= X"262";

				when X"91" =>
					instruction_info <= X"262";

			--	STX
			--	Store X in memory
			--	X -> M
			--
				when X"86" =>
					instruction_info <= X"232";
				when X"96" =>
					instruction_info <= X"242";
				when X"8e" =>
					instruction_info <= X"342";

			--	STY
			--	Store y in memory
			--	Y_REG -> M 
			--
				when X"84" =>
					instruction_info <= X"232";
				when X"94" =>
					instruction_info <= X"242";
				when X"8c" =>
					instruction_info <= X"342";

			--	TAX
			--	Transfer A_REG to X
			--	A_REG -> X
			--	N & Z
			--
				when X"AA" =>
					instruction_info <= X"127";

			-- 	TAY 
			--	X-fer A_REG to Y_REG
			--	A_REG -> Y_REG
			--	N & Z
			--	
				when X"a8" =>
					instruction_info <= X"127";

			--	TYA
			--	X-fer Y_REG to A_REG
			--	Y_REG -> A_REG
			--	N & Z
			--
				when X"98" =>
					instruction_info <= X"127";

			--	TSX
			--	X-fer stack pointer to X
			--	S -> X
			--	N & Z
			--	
				when X"ba" =>
					instruction_info <= X"127";

			--	TXA
			--	X-fer X to Accumulator
			--	X -> A_REG
			--	N & Z
			--	
				when X"8A" =>
					instruction_info <= X"127";

			--	TXS
			--	X-fer X to stack pointer
			--	X -> S
			--	
				when X"9a" =>
					instruction_info <= X"127";

			--	XBA
			--	Exchange B & A_REG Accumulators
			--	A_REG <-> B
			--	Remeber that A_REG is the lower 8 bits of C_FLAG
			--		and that B is the upper 8 bits of C_FLAG
			--
				when X"EB" =>
					instruction_info <= X"137";

			--	XCE
			--	Exchange Carry and Emulation flags
			--	E Flag <-> C_FLAG Flag
			--		Even though this manipulates
			--			flag bits, note that it is
			--			EXCHANGE type instruction for
			--			this implementation.
			--
				when X"FB" =>
					instruction_info <= X"127";

			--
			--	All other instructions are NOP's
			--
				when others =>
					instruction_info <= X"126";

			end case;

			decode_done <= '1';
		end if;
	end process;

end architecture;
