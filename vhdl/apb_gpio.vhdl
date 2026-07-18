library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity apb_gpio is 
    generic (
        ADDR_WIDTH : positive := 32;
        DATA_WIDTH : positive := 32; 
        GPIO_WIDTH : positive := 8;
        WAIT_STATES : natural := 0
    );
    port (
        -- APB3 interface 
        PCLK : in std_logic;
        PRESETn : in std_logic;
        PSEL : in std_logic;
        PENABLE : in std_logic;
        PWRITE : in std_logic;
        PADDR : in std_logic_vector(ADDR_WIDTH -1 downto 0);
        PWDATA : in std_logic_vector(DATA_WIDTH -1 downto 0);

        PRDATA : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        PREADY : out std_logic;
        PSLVERR : out std_logic;

        -- GPIO interface 
        GPIO_IN : in std_logic_vector(GPIO_WIDTH - 1 downto 0);
        GPIO_OUT : out std_logic_vector(GPIO_WIDTH-1 downto 0);
        GPIO_OE : out std_logic_vector(GPIO_WIDTH-1 downto 0)

    );

end entity apb_gpio;
architecture rtl of apb_gpio is 
    -- register map 
    -- 0x00 : GPIO_OUT register, r/w
    -- 0x04 : GPIO_IN register, read-only 
    -- Ox08 : GPIO_DIR register, r/w
    constant ADDR_GPIO_OUT : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(16#00#, ADDR_WIDTH);
    constant ADDR_GPIO_IN : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(16#04#, ADDR_WIDTH);
    constant ADDR_GPIO_DIR : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(16#08#, ADDR_WIDTH);

    signal gpio_out_reg : std_logic_vector(GPIO_WIDTH-1 downto 0);
    signal gpio_dir_reg : std_logic_vector(GPIO_WIDTH-1 downto 0);

    signal wait_count : natural range 0 to WAIT_STATES := 0;
    signal address_valid : std_logic;
    signal write_valid : std_logic;
    signal transfer_done : std_logic;

begin 
    assert DATA_WIDTH >= GPIO_WIDTH
        report "Data width must be greater than or equal to GPIO_WIDTH"
        severity failure;

        GPIO_OUT <= gpio_out_reg; 
        GPIO_OE <= gpio_dir_reg; 

    
    -- address decoding 
    process (all) 
    begin 
        address_valid <= '0';

        if unsigned(PADDR) = ADDR_GPIO_OUT or
           unsigned(PADDR) = ADDR_GPIO_IN or
           unsigned(PADDR) = ADDR_GPIO_DIR then
            address_valid <= '1';
        else
            address_valid <= '0';
        end if;
    end process;


    -- read-only GPIO_IN
    process (all)
    begin 
        write_valid <='1';
        if PWRITE = '1' and unsigned (PADDR) = ADDR_GPIO_IN then 
            write_valid <= '0';
        end if;
    end process;


    process (PCLK, PRESETn)
    begin 
        if PRESETn = '0' then 
            wait_count <= 0;
        
        elsif rising_edge(PCLK) then 
            if PSEL = '1' and PENABLE = '0' then 
                wait_count <= WAIT_STATES; 
            
            elsif PSEL = '1' and PENABLE = '1' then 
                if wait_count > 0 then 
                    wait_count <= wait_count - 1; 
                end if;
            
            else wait_count <= 0; 
            end if; 
        
        end if; 
    end process; 

    PREADY <= '1' when 
        PSEL = '1' and PENABLE = '1' and wait_count = 0
        else '0'; 
    
    transfer_done <= PSEL and PENABLE and PREADY;


    -- ERORR response 
    PSLVERR <= '1' when 
        transfer_done = '1' and 
        (address_valid = '0' or write_valid = '0')
        else '0';
    
    -- Register write
    process(PCLK, PRESETn)
    begin 
        if PRESETn = '0' then 
            gpio_out_reg <= (others => '0'); 
            gpio_dir_reg <= (others => '0');
        
        elsif rising_edge(PCLK) then 
            if transfer_done = '1' and 
               PWRITE = '1' and 
               address_valid = '1' and 
               write_valid = '1' then 
               if unsigned(PADDR) = ADDR_GPIO_OUT then
                   gpio_out_reg <= PWDATA(GPIO_WIDTH -1 downto 0);
               elsif unsigned(PADDR) = ADDR_GPIO_DIR then
                   gpio_dir_reg <= PWDATA(GPIO_WIDTH - 1 downto 0);
               end if;
            end if; 
        end if; 
    end process; 
    
    
    -- Register reads 
    process(all) 
        variable read_data : std_logic_vector(DATA_WIDTH - 1 downto 0);
    begin 
        read_data := (others => '0');

        if unsigned(PADDR) = ADDR_GPIO_OUT then
            read_data(GPIO_WIDTH -1 downto 0) := gpio_out_reg;
        elsif unsigned(PADDR) = ADDR_GPIO_IN then
            read_data(GPIO_WIDTH -1 downto 0) := GPIO_IN;
        elsif unsigned(PADDR) = ADDR_GPIO_DIR then
            read_data(GPIO_WIDTH -1 downto 0) := gpio_dir_reg;
        else
            read_data := (others => '0');
        end if;

        PRDATA <= read_data; 
    
    end process; 

end architecture rtl; 
