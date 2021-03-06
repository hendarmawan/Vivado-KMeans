----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London
-- 
-- Module Name: testbench - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under a BSD license, see LICENSE.txt
-- 
----------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;
use ieee.math_real.all;
use STD.textio.all;
use work.lloyds_algorithm_pkg.all;
 
ENTITY testbench IS
END testbench;
 
ARCHITECTURE behavior OF testbench IS 
 
    constant MY_N : integer := 128; --N
    constant MY_K : integer := 4; -- K
 
    file my_input_node : TEXT open READ_MODE is "../../simulation/data_points_N128_K4_D3_s0.75.mat";
    file my_input_cntr : TEXT open READ_MODE is "../../simulation/initial_centres_N128_K4_D3_s0.75_1.mat";   	
    --file my_input_node : TEXT open READ_MODE is "../../simulation/data_points_N16384_K256_D3_s0.20.mat";
    --file my_input_cntr : TEXT open READ_MODE is "../../simulation/initial_centres_N16384_K256_D3_s0.20_1.mat";
    --file my_input_node : TEXT open READ_MODE is "../../simulation/data_points_N16384_K128_D3_s0.00.mat";
    --file my_input_cntr : TEXT open READ_MODE is "../../simulation/initial_centres_N16384_K128_D3_s0.00_1.mat";   
 
    -- Clock period definitions
    constant CLK_PERIOD : time := 10 ns;
    constant RESET_CYCLES : integer := 20;        
    constant INIT_CYCLES : integer := MY_N;    
 
    type state_type is (readfile, reset, init, processing, processing_done);
    
    type file_node_data_array_type is array(0 to D-1, 0 to MY_N-1) of integer;
    type file_cntr_data_array_type is array(0 to D-1, 0 to MY_K-1) of integer;
     
	
    -- Component Declaration for the Unit Under Test (UUT)
    component lloyds_algorithm_top
        port (
            clk : in std_logic;
            sclr : in std_logic;
            start : in std_logic; 
            -- initial parameters    
            n : in node_index_type;            
            k : in centre_index_type;
            -- init node and centre memory 
            wr_init_node : in std_logic;
            wr_node_address_init : in node_address_type;
            wr_node_data_init : in node_data_type;
            wr_init_pos : in std_logic;
            wr_centre_list_pos_address_init : in centre_index_type;
            wr_centre_list_pos_data_init : in data_type;
            -- outputs
            valid : out std_logic;
            clusters_out : out data_type;
            distortion_out : out coord_type_ext;     
            -- processing done       
            rdy : out std_logic       
        );
    end component;

   --Inputs   
    signal clk : std_logic;
    signal sclr : std_logic := '1';
    signal start : std_logic := '0'; 
    -- initial parameters        
    signal n : node_index_type;            
    signal k : centre_index_type;    
    -- init node and centre memory
    signal wr_init_node : std_logic := '0';
    signal wr_node_address_init : node_address_type;
    signal wr_node_data_init : node_data_type;
    signal wr_init_pos :  std_logic := '0';
    signal wr_centre_list_pos_address_init : centre_index_type;
    signal wr_centre_list_pos_data_init : data_type;
   
   -- Outputs   
    signal valid : std_logic;
    signal clusters_out : data_type;
    signal distortion_out : coord_type_ext;
    signal rdy : std_logic;
      	      	
   -- file io
   signal file_node_data_array : file_node_data_array_type;
   signal file_cntr_data_array : file_cntr_data_array_type;
   signal read_file_done : std_logic := '0';   
    
   -- Operation
    signal state : state_type := readfile;
    signal reset_counter : integer := 0;
    signal init_counter : integer := 0;  
    signal reset_counter_done : std_logic := '0';
    signal init_counter_done : std_logic := '0';    
	
 
BEGIN       
 
    -- Instantiate the Unit Under Test (UUT)
    uut : lloyds_algorithm_top
        port map (
            clk => clk,
            sclr => sclr,
            start => start ,
            -- initial parameters 
            n => n,               
            k => k, 
            -- init node and centre memory
            wr_init_node => wr_init_node,
            wr_node_address_init => wr_node_address_init,
            wr_node_data_init => wr_node_data_init,
            wr_init_pos => wr_init_pos,
            wr_centre_list_pos_address_init => wr_centre_list_pos_address_init,
            wr_centre_list_pos_data_init => wr_centre_list_pos_data_init,
            -- outputs
            valid => valid,
            clusters_out => clusters_out,
            distortion_out => distortion_out,            
            -- final result available       
            rdy => rdy         
        );
    
    -- Clock process definitions
    clk_process : process
    begin
        clk <= '1';
        wait for CLK_PERIOD/2;
        clk <= '0';
        wait for CLK_PERIOD/2;
    end process;
 
    fsm_proc : process(clk)
    begin
        if rising_edge(clk) then
            if state = readfile AND read_file_done = '1' then
                state <= reset;
            elsif state = reset AND reset_counter_done = '1' then
                state <= init;
            elsif state = init AND init_counter_done = '1' then
                state <= processing;  
            elsif state = processing AND rdy = '1' then
                state <= processing_done;                                    
            end if;                                    
        end if;
    end process fsm_proc;
            
    
    counter_proc : process(clk)
    begin
        if rising_edge(clk) then
        
            if state = reset then
                reset_counter <= reset_counter+1;
            end if;
            
            if state = init then
                init_counter <= init_counter+1;
            end if;
            
        end if;
    end process counter_proc;
    
    reset_counter_done <= '1' WHEN reset_counter = RESET_CYCLES-1 ELSE '0';
    init_counter_done <= '1' WHEN init_counter = INIT_CYCLES-1 ELSE '0';
    
   
    reset_proc : process(state)
    begin
        if state = reset then
            sclr <= '1';
        else
            sclr <= '0';
        end if;
    end process reset_proc;
        
 
    init_proc : process(state, init_counter)
        variable centre_pos : data_type;
        variable node : node_data_type; 
    begin
    
        if state = init then        
            
            -- centre_positions_memory
            if init_counter < MY_K then
                for I in 0 to D-1 loop
                    centre_pos(I) := std_logic_vector(to_signed(file_cntr_data_array(I,init_counter),COORD_BITWIDTH));
                end loop;
                wr_init_pos <= '1'; 
                wr_centre_list_pos_address_init <= to_unsigned(init_counter,INDEX_BITWIDTH);
                wr_centre_list_pos_data_init <= centre_pos;                
            else
                wr_init_pos <= '0'; 
            end if;
              
            -- tree_node_memory
            if init_counter < MY_N   then 
                for I in 0 to D-1 loop 
                    node.position(I) := std_logic_vector(to_signed(file_node_data_array(I,init_counter),COORD_BITWIDTH));                
                end loop;             
                wr_init_node <= '1';                   
                wr_node_address_init <= std_logic_vector(to_unsigned(init_counter,NODE_POINTER_BITWIDTH));
                wr_node_data_init <= node;
            else
                wr_init_node <= '0'; 
            end if;                        
            
        else            
            wr_init_node <= '0';
            wr_init_pos <= '0';
        end if;
    end process init_proc;
    
    
    processing_proc : process(state, init_counter_done) 
    begin
        if state = init AND init_counter_done = '1' then
            start <= '1';
            k <= to_unsigned(MY_K-1,INDEX_BITWIDTH);
            n <= to_unsigned(MY_N-1,NODE_POINTER_BITWIDTH);
        else 
            start <= '0';
        end if;
        
    end process processing_proc;           
 		
	
	-- read tree data and initial centres from file
    read_file : process
 	
    	variable my_line : LINE;
    	variable my_input_line : LINE;
    	variable tmp_line_counter_node : integer;
    	variable tmp_file_line_counter_node : integer;
    	variable tmp_line_counter_cntr : integer;
    	variable tmp_file_line_counter_cntr : integer;
    	variable tmp_d : integer;    	
    	variable tmp_file_data_node : file_node_data_array_type;
    	variable tmp_file_data_cntr : file_cntr_data_array_type;
    begin
    	write(my_line, string'("reading input files"));		
    	writeline(output, my_line);	
    	
    	tmp_line_counter_node := 0;
    	tmp_file_line_counter_node := 0;
    	tmp_d := 0;    	
    	loop
    		exit when endfile(my_input_node) OR tmp_line_counter_node = D*MY_N;
    		readline(my_input_node, my_input_line);
    		read(my_input_line,tmp_file_data_node(tmp_d,tmp_file_line_counter_node));
--    		if tmp_line_counter_node < MY_N then		    		
--    	       read(my_input_line,tmp_file_data_node(0,tmp_line_counter_node));
--    	    else
--    	       read(my_input_line,tmp_file_data_node(1,tmp_line_counter_node-MY_N));
--    	    end if;     	     			
    		tmp_line_counter_node := tmp_line_counter_node+1;
    		tmp_file_line_counter_node := tmp_file_line_counter_node+1;
    		if tmp_file_line_counter_node = MY_N then
    		  tmp_d := tmp_d +1;
    		  tmp_file_line_counter_node := 0;
    		end if;    		
    	end loop;
    	    	
    	file_node_data_array <= tmp_file_data_node;
    	
    	write(my_line, string'("Number of lines:"));
    	writeline(output, my_line);
    	write(my_line, tmp_line_counter_node);
    	writeline(output, my_line);
    	
    	-- reading centres now
    	tmp_line_counter_cntr := 0;
    	tmp_file_line_counter_cntr := 0;
    	tmp_d := 0;     	    	
    	loop
    		exit when endfile(my_input_cntr) OR tmp_line_counter_cntr = D*MY_K;
    		readline(my_input_cntr, my_input_line);	
            read(my_input_line,tmp_file_data_cntr(tmp_d,tmp_file_line_counter_cntr));    		
--    		if tmp_line_counter_cntr < MY_K then		    		
--    	       read(my_input_line,tmp_file_data_cntr(0,tmp_line_counter_cntr));
--    	    else
--    	       read(my_input_line,tmp_file_data_cntr(1,tmp_line_counter_cntr-MY_K));
--    	    end if;    		
    		tmp_line_counter_cntr := tmp_line_counter_cntr+1;
    		tmp_file_line_counter_cntr := tmp_file_line_counter_cntr+1;
    		if tmp_file_line_counter_cntr = MY_K then
    		  tmp_d := tmp_d +1;
    		  tmp_file_line_counter_cntr := 0;
    		end if;      		
    	end loop;
    	    	
    	file_cntr_data_array <= tmp_file_data_cntr;
    	
    	write(my_line, string'("Number of lines:"));
    	writeline(output, my_line);
    	write(my_line, tmp_line_counter_cntr);
    	writeline(output, my_line);    	
    	
    	read_file_done <= '1';
    	wait; -- one shot at time zero,
    	
    end process read_file;	
		
	
END;
