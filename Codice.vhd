-----------------------------------------------------------------------------------------------------------------------
-- Giovanni Paolino -- Codice Persona: 10696774
-- Ilaria Paratici -- Codice Persona: 10707097
------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
port (
i_clk : in std_logic;
i_rst : in std_logic;
i_start : in std_logic;
i_data : in std_logic_vector(7 downto 0);
o_address : out std_logic_vector(15 downto 0);
o_done : out std_logic;
o_en : out std_logic;
o_we : out std_logic;
o_data : out std_logic_vector (7 downto 0)
);
end project_reti_logiche;
-----------------------------------------------------------------------------------------------------------------------

architecture Behavioral of project_reti_logiche is
    
    component FSM_codificatore is
    port(   
        init : in std_logic;
        i: in integer range 0 to 7;
        i_data: in std_logic_vector(7 downto 0);
        clk: in std_logic;
        rst: in std_logic;
        start: in std_logic;
        enable: in std_logic;
        output: out std_logic_vector (1 downto 0));
    end component;

    --STOP stato di pronto
    --A preparazione della computazione con lettura del numero delle parole (w) e allineamento dell'offset
    --B lettura delle parole una alla volta
    --C computazione della parola letta e creazione delle due parole di output
    --W scrittura in memoria
    --D fine con segnale o_done alto

    type state_type is (STOP, A0, A1, A2, A3, B, C0, C1, C2, C3, C4, C5, C6, C7, C8, W1, W2, D); --stati del blocco principale
    
    signal NS, CS: state_type;                         --stati prossimo e corrente del blocco principale
    
    signal w: integer range 0 to 1000;                 --numero di parole da leggere
    signal offset: integer range 0 to 1000;
    signal i: integer range 0 to 7;                    --singolo bit passato al processo di codifica
    signal output: std_logic_vector (1 downto 0);      --coppia di bit in uscita dal processo di codifica
    
    signal parola1: std_logic_vector (7 downto 0);
    signal parola2: std_logic_vector (7 downto 0);
    
                                                       --o1,o1_bis, o2, o3, o4 salvataggi temporanei degli output del codificatore
    signal o1: std_logic_vector (1 downto 0); 
    signal o1_bis: std_logic_vector (1 downto 0);
    signal o2: std_logic_vector (1 downto 0);
    signal o2_bis: std_logic_vector (1 downto 0);
    signal o3: std_logic_vector (1 downto 0);
    signal o3_bis: std_logic_vector (1 downto 0);
    signal o4: std_logic_vector (1 downto 0);
    signal o4_bis: std_logic_vector (1 downto 0);
    
    signal ONcodificatore: std_logic;                  --segnale per attivare/disattivare l'avanzamento degli stati del codificatore
    signal nuovo_start: std_logic;                     --segnale che mi dice se ho appena iniziato una nuova elaborazione
    signal init_codificatore: std_logic;               --se alto ricomincio la computazione del codificatore dallo stato iniziale S0
-----------------------------------------------------------------------------------------------------------------------

begin  
    
    codificatore: FSM_codificatore
       port map(
           init => init_codificatore,
           i => i, 
           rst => i_rst, 
           clk => i_clk,
           i_data => i_data,
           start => i_start,
           enable => ONcodificatore,
           output => output);
        
    STATE_MANAGER: process(i_clk,i_rst,i_start)
    begin
        if i_rst = '0' and i_start = '0' then
            CS <= STOP;
        elsif rising_edge(i_rst) or rising_edge(i_start) then 
            CS <= A0;
        elsif rising_edge(i_clk) then
            CS <= NS;
        end if;
    end process;
-----------------------------------------------------------------------------------------------------------------------

    MAIN: process(CS,i_start,nuovo_start)
    begin
        if i_start = '1' then
          case CS is
            when STOP =>
                init_codificatore <= '0';
                
            when A0 => --stato di reset
                nuovo_start <= '1';
                offset <= 0;
                o_address <= "0000000000000000";
                o_we <= '0';
                o_en <= '1';
                NS <= A1;
            when A1 => --ci serve per aspettare i 2ns della memoria
                NS <= A2;                       
            when A2 => --leggo w
                w <= conv_integer(i_data);
                o_en <= '0';
                NS <= A3;
            when A3 => --incrementa l'offset di lettura
                offset <= offset + 1;
                o_en <= '0'; --perché torno in A3 dopo W2
                o_we <= '0';
                NS <= B;
            when B => --setta address per leggere la parola
                o_address <= std_logic_vector(to_unsigned(offset,o_address'length));
                o_en <= '1';
                if w = 0 then
                    NS <= D;
                else
                    NS <= C0;
                end if;
            when C0 => --inizio elaborazione dei miei bit
                o_en <= '0';
                if nuovo_start = '1' then
                    init_codificatore <= '1';
                    nuovo_start <= '0';
                end if;
                ONcodificatore <= '1'; --attivo codificatore
                i <= 7;
                NS <= C1;
            when C1 =>
                init_codificatore <= '0';
                o1 <= output;
                i<=6;
                NS <= C2;
            when C2 =>
                o2 <= output;
                i<=5;
                NS <= C3;
            when C3 =>
                o3 <= output;
                i<=4;
                NS <= C4;
            when C4 =>
                o4 <= output;
                i<=3;
                NS <= C5;
            when C5 =>
                parola1 <= o1&o2&o3&o4;
                o1_bis <= output;
                i<=2;
                NS<=C6;
            when C6 =>
                o2_bis <= output;
                i<=1;
                NS <= C7;
            when C7 =>
                o3_bis <= output;
                i<=0;
                NS <= C8;
            when C8 => 
                o4_bis <= output;
                ONcodificatore <= '0'; --disattivo il codificatore
                NS <= W1;
                
            when W1 => --scrivo la prima parola in memoria
                parola2 <= o1_bis&o2_bis&o3_bis&o4_bis;
                o_data <= parola1;
                o_address <= std_logic_vector(to_unsigned(1000 + 2*(offset-1), o_address'length));
                o_we <= '1';
                o_en <= '1';
                NS <= W2;
            when W2 => --scrivo la seconda parola in memoria
                o_data <= parola2;
                o_address <= std_logic_vector(to_unsigned(1000 + 2*(offset-1) +1, o_address'length));
                o_we <= '1';
                o_en <= '1';
                if w = offset then
                    NS <= D;
                else
                    NS <= A3;
                end if;
                
            when D =>
                o_done <= '1';
                
          end case;
        elsif i_start = '0' then
            o_done <= '0';  
        end if;
    end process;   
end Behavioral;


-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
--
-- Codificatore
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

entity FSM_codificatore is
port(   
        init : in std_logic;
        i: in integer range 0 to 7;
        clk: in std_logic;
        rst: in std_logic;
        i_data: in std_logic_vector(7 downto 0);
        start: in std_logic;
        enable: in std_logic;
        output: out std_logic_vector (1 downto 0));
end FSM_codificatore;

architecture Behavioral of FSM_codificatore is

type state_type is (S0, S1, S2, S3);
signal next_state, current_state: state_type;

begin

    STATE_MANAGER: process(clk,rst,start,init)
    begin
        if init = '1' then
                current_state <= S0;
        end if;
        if rising_edge(rst) or rising_edge(start) then 
            current_state <= S0;
        else if rising_edge(clk) then 
            current_state <= next_state;
        end if;
        end if;
    end process;
    
    DELTA_CODIFICATORE: process(current_state,i_data,i,enable)
    begin
        case current_state is
            when S0 => if i_data(i)='0' then 
                            if falling_edge(enable) or enable = '0' then
                                next_state <= S0;
                            else 
                                next_state <= S0;
                                output <= "00";
                            end if;
                   
                       elsif falling_edge(enable) or enable = '0' then
                            next_state <= S0;
                           else 
                            next_state <= S2;
                            output <= "11";
                       end if;
                                                                          
            when S1 => if i_data(i)='0' then 
                            if falling_edge(enable) or enable = '0' then
                                next_state <= S1;
                            else 
                                next_state <= S0;
                                output <= "11";
                            end if;
                    
                       elsif falling_edge(enable) or enable = '0' then
                                next_state <= S1;
                            else 
                                next_state <= S2;
                                output <= "00"; 
                       end if;
                                          
            when S2 => if i_data(i)='0' then 
                            if falling_edge(enable) or enable = '0' then
                                next_state <= S2;
                            else 
                                next_state <= S1;
                                output <= "01";
                            end if;
                   
                       elsif falling_edge(enable) or enable = '0' then
                                next_state <= S2;
                            else 
                                next_state <= S3;
                                output <= "10";
                       end if;

            when S3 => if i_data(i)='0' then 
                            if falling_edge(enable) or enable = '0' then
                                next_state <= S3;
                            else
                                next_state <= S1;
                                output <= "10";
                            end if;
                    
                       elsif falling_edge(enable) or enable = '0' then
                                next_state <= S3;
                            else 
                                next_state <= S3;
                                output <= "01";
                       end if;
        end case;
    end process;
end Behavioral;