----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/06/2024 03:57:16 PM
-- Design Name: 
-- Module Name: fp_adder_sig - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fp_adder_sig is
    Port ( 
            i_clk : in STD_LOGIC;
            aresetn : IN STD_LOGIC;
            s_axis_a_tvalid : IN STD_LOGIC;
            s_axis_a_tready : OUT STD_LOGIC;
            s_axis_a_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            s_axis_b_tvalid : IN STD_LOGIC;
            s_axis_b_tready : OUT STD_LOGIC;
            s_axis_b_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            m_axis_result_tvalid : OUT STD_LOGIC;
            m_axis_result_tready : IN STD_LOGIC;
            m_axis_result_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
end fp_adder_sig;

architecture Behavioral of fp_adder_sig is

type t_state is (
                    idle,
                    switch1,
                    switch2,
                    check_zero,
                    execute_zero,
                    switch3,
                    denormalize1,
                    denormalize2,
                    denormalize3,
                    denormalize4,
                    add_mantissa0,
                    add_mantissa1,
                    add_mantissa2,
                    add_mantissa3,
                    add_mantissa4,
                    add_mantissa5,
                    normalize1,
                    normalize2,
                    normalize3,
                    normalize4,
                    end_add1,
                    end_add2,
                    end_add3,
                    end_add4
                    );
signal pr_state : t_state := idle;

signal larger_sign : std_logic;
signal larger_exponent : unsigned(7 downto 0);
signal larger_mantissa : unsigned(6 downto 0);

signal smaller_sign : std_logic;
signal smaller_exponent : unsigned(7 downto 0);
signal smaller_mantissa : unsigned(6 downto 0);     

signal result_sign : std_logic;
signal result_exponent : unsigned(7 downto 0);
signal result_mantissa : unsigned(6 downto 0);
signal result_mantissa_int : unsigned (8 downto 0);

signal result_vector : std_logic_vector(15 downto 0);

signal zero_exponent : unsigned (7 downto 0) := (others => '0');
signal zero_mantissa : unsigned(6 downto 0) := (others => '0');
           

begin
    
    process(i_clk,aresetn)
        variable s_le : signed(7 downto 0);
        variable u_lm : unsigned(6 downto 0);
        variable s_se : signed(7 downto 0);
        variable u_sm : unsigned(6 downto 0);
        variable exponent_diff : integer := 0;
        variable i_se : integer := 0;
        variable i_le : integer := 0;
        variable leading_zero_count : integer := 0;
        variable pos_count : integer := 0;
        constant max_pos : integer := 6;
        
        variable sm_int : unsigned(8 downto 0) := (others => '0');
        variable lm_int : unsigned(8 downto 0) := (others => '0');
        
        
    begin
        if rising_edge(i_clk) then
            if aresetn = '0' then
                pr_state <= idle;
            else
                case pr_state is 
                when idle =>
                    s_le := (others => '0');
                    u_lm := (others => '0');
                    s_se := (others => '0');
                    u_sm := (others => '0');
                    exponent_diff := 0;
                    i_se := 0;
                    i_le := 0;
                    
                    leading_zero_count := 0;
                    pos_count := 0;
                    
                    sm_int := (others => '0');
                    lm_int := (others => '0');
                    
                    larger_sign <= '0';
                    larger_exponent <= (others => '0');
                    larger_mantissa <= (others => '0');
                    
                    smaller_sign <= '0';
                    smaller_exponent <= (others => '0');
                    smaller_mantissa <= (others => '0');
                    
                    result_sign <= '0';
                    result_exponent <= (others => '0');
                    result_mantissa <= (others => '0');
                    result_mantissa_int <= (others => '0');
                    
                    result_vector <= (others => '0');
                    
                    s_axis_a_tready <= '1';
                    s_axis_b_tready <= '1';
                    --s_axis_operation_tready <= '1';
                    m_axis_result_tvalid <= '0';
                    if s_axis_a_tvalid = '1' and s_axis_b_tvalid = '1' then
                        pr_state <= switch1;
                    else
                        pr_state <= idle;
                    end if;
                
                when switch1 =>
                    s_axis_a_tready <= '0';
                    s_axis_b_tready <= '0';
                    --s_axis_operation_tready <= '0';
                    m_axis_result_tvalid <= '0';
                    larger_sign <= s_axis_a_tdata(15);
                    larger_exponent <= unsigned(s_axis_a_tdata(14 downto 7));
                    larger_mantissa <= unsigned(s_axis_a_tdata(6 downto 0));
                    
                    smaller_sign <= s_axis_b_tdata(15);
                    smaller_exponent <= unsigned(s_axis_b_tdata(14 downto 7));
                    smaller_mantissa <= unsigned(s_axis_b_tdata(6 downto 0));
                    
                    
                    
                    pr_state <= switch2;
                    
                when switch2 =>
                    if unsigned(larger_exponent) < unsigned(smaller_exponent) then
                        larger_sign <= smaller_sign;
                        larger_exponent <= smaller_exponent;
                        larger_mantissa <= smaller_mantissa;
                        
                        smaller_sign <= larger_sign;
                        smaller_exponent <= larger_exponent;
                        smaller_mantissa <= larger_mantissa;
                    end if;
                    pr_state <= check_zero;
                    
                when check_zero =>
                    if smaller_exponent = zero_exponent and smaller_mantissa = zero_mantissa then
                        pr_state <= execute_zero;
                    else
                        pr_state <= denormalize1;
                    end if;
                    
                when execute_zero =>
                    result_sign <= larger_sign;
                    result_exponent <= larger_exponent;
                    result_mantissa_int(6 downto 0) <= larger_mantissa;
                    pr_state <= end_add1;
                    
                when denormalize1 =>
                    i_le := to_integer(larger_exponent);
                    i_se := to_integer(smaller_exponent);
                    
                    sm_int(6 downto 0) := smaller_mantissa;
                    lm_int(6 downto 0) := larger_mantissa;
                    sm_int(7) := '1';
                    lm_int(7) := '1';
                    pr_state <= denormalize2;
                    
                when denormalize2 =>
                    exponent_diff := i_le - i_se;
                    
                    pr_state<= denormalize3;
                    
                when denormalize3 =>
                    smaller_exponent <= larger_exponent;
                    sm_int := shift_right(sm_int,exponent_diff);
                    pr_state <= add_mantissa1;
                    
--                when add_mantissa0 =>
--                    sm_int(6 downto 0) := smaller_mantissa;
--                    lm_int(6 downto 0) := larger_mantissa;
--                    pr_state <= add_mantissa1;
                    
                when add_mantissa1 =>
                    if smaller_sign = '0' and larger_sign = '0' then --both positive
                        result_sign <= '0';
                        result_exponent <= larger_exponent;
                        result_mantissa_int <= sm_int + lm_int;
                        pr_state <= normalize1;
                    else
                        pr_state <= add_mantissa2;
                    end if;
                
                when add_mantissa2 =>
                    if smaller_sign = '0' and larger_sign = '1' then --larger is negative
                        result_sign <= '1';
                        result_exponent <= larger_exponent;
                        result_mantissa_int <= lm_int - sm_int;
                        pr_state <= normalize1;
                    else
                        pr_state <= add_mantissa3;
                    end if;   
                    
                when add_mantissa3 =>
                    if smaller_sign = '1' and larger_sign = '0' then --smaller is negative
                        result_sign <= '0';
                        result_exponent <= larger_exponent;
                        result_mantissa_int <= lm_int - sm_int;
                        pr_state <= normalize1;
                    else
                        pr_state <= add_mantissa4;
                    end if;  
                    
                when add_mantissa4 =>
                    if smaller_sign = '1' and larger_sign = '1' then --both negative
                        result_sign <= '1';
                        result_exponent <= larger_exponent;
                        result_mantissa_int <= lm_int + sm_int;
                        pr_state <= normalize1;
                    else
                        pr_state <= normalize1;
                    end if; 
                
                when normalize1 =>
                    leading_zero_count := -1;
                    pos_count := 8;
                    --result_mantissa <= result_mantissa_int(7 downto 1);
                    pr_state <= normalize2;
                    
                when normalize2 =>
                    if pos_count < 0 then
                        pr_state <= normalize4;
                    else
                        pr_state <= normalize3;
                    end if;
                    
                when normalize3 =>
                    if result_mantissa_int(pos_count) = '1' then
                        pr_state <= normalize4;
                    else
                        pos_count := pos_count - 1;
                        leading_zero_count := leading_zero_count + 1;
                        pr_state <= normalize2;
                    end if;
                
                when normalize4 =>
                    result_exponent <= result_exponent - leading_zero_count;
                    result_mantissa_int <= shift_left(result_mantissa_int,leading_zero_count);
                    pr_state <= end_add1;
                    
                when end_add1 =>
                    result_vector(15) <= result_sign;
                    result_vector(14 downto 7) <= std_logic_vector(result_exponent);
                    result_vector(6 downto 0) <= std_logic_vector(result_mantissa_int(6 downto 0));
                    pr_state <= end_add2;
                    
                when end_add2 =>
                    if m_axis_result_tready = '1' then
                        pr_state <= end_add3;
                    else
                        pr_state <= end_add2;
                    end if;
                
                when end_add3 =>
                    m_axis_result_tdata <= result_vector;
                    m_axis_result_tvalid <= '1';
                    if s_axis_a_tvalid = '0' and s_axis_b_tvalid = '0' then
                        pr_state <= idle;
                    else
                        pr_state <= end_add3;
                    end if;   
                
                 
                    
                            
                    
                when others =>
                    pr_state <= idle;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
