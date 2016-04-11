library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package SNES65816func is

	function reverse_any_vector (a: in std_logic_vector)
		return std_logic_vector;
		
		
	FUNCTION "+" (L:std_logic_vector; R: std_logic_vector) RETURN std_logic_vector;
	FUNCTION "+" (L:std_logic_vector; R: integer) RETURN std_logic_vector;
	FUNCTION "-" (L:std_logic_vector; R: std_logic_vector) RETURN std_logic_vector;
	FUNCTION "-" (L:std_logic_vector; R: integer) RETURN std_logic_vector;
	

end package;

package body SNES65816func is


	function "+"(L: STD_LOGIC_VECTOR; R: STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
		constant length: INTEGER := L'length;
		variable result : STD_LOGIC_VECTOR (length-1 downto 0);
	begin
		result := std_logic_vector(SIGNED(L) + SIGNED(R)); 
		return result;
	end;
	
	function "-"(L: STD_LOGIC_VECTOR; R: STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
		constant length: INTEGER := R'length;
		variable result : STD_LOGIC_VECTOR (length-1 downto 0);
	begin
		result := std_logic_vector(SIGNED(L) - SIGNED(R)); 
		return result;
	end;
	
	function "-"(L: STD_LOGIC_VECTOR; R: integer) return STD_LOGIC_VECTOR is
		constant length: INTEGER := L'length;
		variable result : STD_LOGIC_VECTOR (length-1 downto 0);
	begin
		result := std_logic_vector(SIGNED(L) - (R)); 
		return result;
	end;
	
	function "+"(L: STD_LOGIC_VECTOR; R: integer) return STD_LOGIC_VECTOR is
		constant length: INTEGER := L'length;
		variable result : STD_LOGIC_VECTOR (length-1 downto 0);
	begin
		result := std_logic_vector(SIGNED(L) + (R)); 
		return result;
	end;
	
	
	function reverse_any_vector (a: in std_logic_vector)
		return std_logic_vector is
			variable result: std_logic_vector(a'RANGE);
			alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
	begin
		for i in aa'RANGE loop
			result(i) := aa(i);
		end loop;
		return result;
	end function; -- function reverse_any_vector		

end SNES65816func;

