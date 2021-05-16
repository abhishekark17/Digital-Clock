--Abhishek kumar
--2019CS10458
-------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM_64Kx8 is
	port (
		clock : in std_logic;
		read_enable, write_enable : in std_logic; -- signals that enable read/write operation
		address : in std_logic_vector(15 downto 0); -- 2^16 = 64K
		data_in : in std_logic_vector(7 downto 0);
		data_out : out std_logic_vector(7 downto 0)
	);
end RAM_64Kx8;
------------------------------------------------------------------------------------------------------
entity ROM_32x9 is
	port (
		clock : in std_logic;
		read_enable : in std_logic; -- signal that enables read operation
		address : in std_logic_vector(4 downto 0); -- 2^5 = 32
		data_out : out std_logic_vector(7 downto 0)
	);
end ROM_32x9;
-------------------------------------------------------------------------------------------------------
entity MAC is
	port (
		clock : in std_logic;
		control : in std_logic; -- ‘0’ for initializing the sum
		data_in1, data_in2 : in std_logic_vector(17 downto 0);
		data_out : out std_logic_vector(17 downto 0)
	);
end MAC;
------------------------------------------------------------------------------------------------------
architecture Artix of RAM_64Kx8 is
	type Memory_type is array (0 to 65535) of std_logic_vector (7 downto 0);
	signal Memory_array : Memory_type;
begin
	process (clock) begin
	if rising_edge (clock) then
		if (read_enable = '1') then -- the data read is available after the clock edge
			data_out <= Memory_array (to_integer (unsigned (address)));
		end if;
		if (write_enable = '1') then -- the data is written on the clock edge
			Memory_array (to_integer (unsigned(address))) <= data_in;
		end if;
	end if;
	end process;
end Artix;
-------------------------------------------------------------------------------------------------------
architecture Artix of ROM_32x9 is
	type Memory_type is array (0 to 31) of std_logic_vector (8 downto 0);
	signal Memory_array : Memory_type;
begin
	process (clock) begin
	if rising_edge (clock) then
		if (read_enable = '1') then -- the data read is available after the clock edge
			data_out <= Memory_array (to_integer (unsigned (address)));
		end if;
	end if;
	end process;
end Artix;
-----------------------------------------------------------------------------------------------------
architecture Artix of MAC is
	signal sum, product : signed (17 downto 0);
begin
	data_out <= std_logic_vector (sum);
	product <= signed (data_in1) * signed (data_in2)
	process (clock) begin
	if rising_edge (clock) then -- sum is available after clock edge
		if (control = '0') then -- initialize the sum with the first product
			sum <= std_logic_vector (product);
		else -- add product to the previous sum
			sum <= std_logic_vector (product + signed (sum));
		end if;
	end if;
	end process;
end Artix;
----------------------------------------------------------------------------------------------------
Entity overall_design IS
	PORT(
		clk:IN std_logic;		--the input clock
		switch:IN std_logic;		--switch which decide whether to sharp or smooth
		push_button:IN std_logic;	--for start command
	);
end overall_design;
----------------------------------------------------------------------------------------------------
architecture Artix of overall_design is
	Type state_type is (S0,S1,S2,S3,S4);
	signal state:state_type:=S0;       
	
	signal read_enable_ram,read_enable_rom,write_enable_ram:bit:='0';		--reading and writing enabling
	
	signal data_in_ram,data_out_ram:std_logic_vector(7 DOWNTO 0):="00000000";	--data_in->data to be stored in RAM, data_out->data to be extracted from RAM
	
	signal data_out_rom:std_logic_vector(8 DOWNTO 0):="000000000";			--data to be extracted from ROM.
	
	signal data_in1,data_in2,data_out:std_logic_vector(17 DOWNTO 0):="000000000000000000"; 		-- These are for MAC inputs and output.
	
	signal count_row_ram,count_column_ram:unsigned(7 DOWNTO 0):="00000000";       	--start col and start row of RAM.
	signal i,j:integer:=0;          					      	--i->row j->col of the nine data.
	signal count:integer:=0;        					      	--module 9 counter.
	
	signal address_ram:std_logic_vector(15 DOWNTO 0):="0000000000000000";    	--address of ram from where data is extracted or given to store.
	signal address_rom:std_logic_vector(7 DOWNTO 0):="00000000";             	--address of rom from where coefficient is extracted.
	
	signal controller_mac:std_logic:='0';					 	--control input for MAC.
	signal sharp:std_logic_vector:='0';					 	--'0' if smoothening or '1' if sharpening. Controlled by switch.
	
begin
	RAM : entity RAM_64Kx8 port map (clk, read_enable_ram, write_enable_ram, address_ram, data_in_ram, data_out_ram);
    	ROM : entity ROM_32x9 port map (clk, read_enable_rom, address_rom, data_out_rom);
    	MAC : entity MAC port map (clk, controller_mac, data_in1, data_in2, data_out);
	
	process(clk) 
	begin
		if(rising_edge(clk)) then
			case state is
				when S0=>			--initailise the filtering process.
					if(push_button='1') then
						count_row_ram<=0;
						count_column_ram<=0;
						if(switch='1') then 
							sharp<='1';
						else
							sharp<='0';
						end if;
						state<=S1;
					end if;
				
				when S1=>		  	--we will come to state after each iteration(i.e. after 9 MAC operation and updating the filtered image).     
					controller_mac<='0';	--we need only the product for the first MAC op.
					count<=0;		--initailise count for the iteration
					i<=0;			--initialise i for the iteration
					j<=0;			--initialise j for the iteraiton
					read_enable_ram<='1';	--read must be enabled for RAM for the first op.
					read_enable_rom<='1';	--write must be disabled for RAM for the first op.
					write_enable_ram<='0';	--read must be enabled for ROM for the first op.
					if(to_integer(count_column_ram)=158) then	--if we have not the end of the image we will continue and update the row and col.
						if(to_integer(count_row_ram)=118) then
							state<=S0;			--if end is reached we will immidiately go to S0. 
						else
							count_column_ram<=0;
							count_row_ram<=count_row_ram+1;
							state<=S2;
						end if;
					else
						count_column_ram<=count_column_ram+1;
						state<=S2;
					end if;
					
				when S2=>		--This is where address of RAM and address of ROM are updated.
					address_rom<=std_logic_vector(to_unsigned(3*i+j+to_integer(sharp)*16,address_rom'length);
					address_ram<=std_logic_vector(to_unsigned((to_integer(count_row_ram)+i)*160+(to_integer(count_column_ram)+j),address_ram'length);
					count<=count+1;
					if(count=0) then 	--move to same state for first time to avoid lag.
						state<=S2;
					else	
						state<=S3;
					end if;
				
				when S3=>
					if(count=1) then	--for first operation only product is needed.
						controller_mac='0';
					else
						controller_mac='1';
					end if;
					data_in1<=std_logic_vector(resize(signed(data_out_ram), data_in1'length));	--data_in1 for MAC converted to 18 bits.
					data_in2<=std_logic_vector(resize(signed(data_out_rom), data_in2'length));	--data_in2 for MAC converted to 18 bits.
					if(j=2) then 				--if both i and j becomes 2 go to next state for writing the value to RAM.
						j<=0;				--else update i and j accordingly and go to S2 for address updatation.
						if(i=2) then
							i<=0;
							state<=S4;
						else 
							i<=i+1;
							state<=S2;
						end if;
					else
						j<=j+1;
						state<=S2;
					end if;
				when S4=>					--This state is used for writing the final MAC output to RAM.
					write_enable_ram<='1';			--write must be enabled for writing to the RAM.
					read_enable_ram<='0';			--We dont need to read at this point.
					read_enable_rom<='0';			--We don't need to read at this point.
					address_ram<=std_logic_vector(to_unsigned((to_integer(count_row_ram))*158+(to_integer(count_column_ram))+32768,address_ram'length);
					if(data_out(17)='0') then		--if MAC output is positive then we need 7  right shifts and ignore the first four bits.
						data_in_ram<=data_out(14 DOWNT0 7);
						state<=S1;			--Go for the next iteration
					else
						data_in_ram<="00000000";	--for negative MAC output(pixel value) we will assign it to 0.
						state<=S1;			--Go for the next iteration.
					end if;
			end case;
		end if;
	end process;
end Artix;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
