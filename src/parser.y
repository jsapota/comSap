%{

#include <common.h>
int yylex(void);
void yyerror(const char *msg);
//cln :: cl_I address = 0;
int address = 0;
static int label = 0;

inline void pomp(int numRegister, uint64_t val);
/* 0 iff ikty bit w n = 0, else 1 */
#define GET_BIT(n , k) ( ((n) & (1ull << k)) >> k )
#define MAX(a,b) ((a) > (b) ? (a) : (b))
%}

/* we need own struct so define it before use in union */
%code requires
{
    #include <string.h>
    #include <map>

    typedef struct yytoken
    {
        char *str;
        int line;
    }yytoken;

    typedef struct Variable
    {

        std :: string name;

        int reg;
        //cln :: cl_I addr;
        int addr;
        int len;

        bool isNum;
        bool upToDate;
        bool array;
        bool init;
        bool iter;

        uint64_t val;

        uint64_t offset; /* t[1000] := a + b   offset = 1000 */
        struct Variable *varOffset; /*  t[b] := a + c  varOffset = ptr --> b*/

    }Variable;
    void inline pomp_addr(int numRegister, Variable const &var);
    void inline variable_copy(Variable &dst, Variable const &src);
    void variable_load(Variable const &var, int numRegister);
    static std :: map<std :: string, Variable> variables;
}

/* override yylval */
%union
{
    yytoken token;
    Variable *var;
}


%token	ASSIGN
%token	NE LE GE
%token	VAR _BEGIN END
%token	READ WRITE SKIP
%token	FOR FROM TO DOWNTO ENDFOR
%token	WHILE DO ENDWHILE
%token	IF THEN ELSE ENDIF
%token	VARIABLE NUM
%token	ERROR

%type <token> VARIABLE vdeclar '[' NUM ']'
%type <var> identifier value

%%


program:
	%empty
	| VAR vdeclar _BEGIN commands END
    {
        std :: cout << "HALT" << std :: endl;
    }
;

vdeclar:
	%empty
	| vdeclar VARIABLE
    {
        /*
            reg = -1;
            addr = -1;
            len = 0;

            array = false;
            init = false;
            upToDate = true;
            iter = false;

            val = 0;
        */
        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address++;
        var.len = 0;
        var.isNum = false;
        var.array = false;
        var.init = false;
        var.upToDate = true;
        var.iter = false;
        var.val = 0;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );
    }
	| vdeclar VARIABLE '[' NUM ']'
    {
        /*
            reg = -1;
            addr = -1;
            len = NUM;

            array = true;
            init = false;
            upToDate = true;
            iter = false;
        */
        auto it = variables.find(std :: string($2.str));
        if (it != variables.end())
        {
            std :: cerr << "REDECLARED\t" << $2.str << std :: endl;
            exit(1);
        }
        Variable var;
        var.name = std :: string($2.str);
        var.reg = -1;
        var.addr = address;
        var.isNum = false;
        var.len = atoll($4.str);
        address += var.len;
        if(var.len == 0)
        {
            std :: cerr << "SIZE OF ARRAY CANT BE 0\t" << $2.str << std :: endl;
            exit(1);
        }
        var.array = true;
        var.init = false;
        var.upToDate = true;
        var.iter = false;
        var.iter = false;
        variables.insert ( std::pair<std :: string,Variable>(var.name,var) );
    }
;

commands:
	command
	| commands command
;

command:
	identifier ASSIGN expr ';'
    {
        if($1->array) {
            if($1->varOffset == NULL){
                pomp_addr(0,*$1); // pomp_addr
                //pomp(0,$1->addr + $1->offset);
            }
            else
            {
                /* zablokowane przez dodawanie */
            }
        }
        else
            pomp_addr(0,*$1); // pomp_addr

        std :: cout << "STORE" << " 1" << std :: endl;

        $1->init = true;
    }
	| IF cond THEN commands ELSE commands ENDIF
	| WHILE cond DO commands ENDWHILE
	| FOR VARIABLE FROM value TO value DO commands ENDFOR
	| FOR VARIABLE FROM value DOWNTO value DO commands ENDFOR
	| READ identifier ';'
    {
        //to robi init
    }
	| WRITE value ';'
    {
        if($2->array) {
            if($2->varOffset == NULL){
                pomp_addr(0,*$2); // pomp_addr
                //pomp(0,$2->addr + $2->offset);
            }
            else
            {
                /* zablokowane przez dodawanie */
            }
        }
        else
            pomp_addr(0,*$2); // pomp_addr

        std :: cout << "LOAD" << " 1" << std :: endl;
        std :: cout << "PUT " << " 1" << std :: endl;

    }
	| SKIP ';'
;

expr:
	value
    {
            if($1->isNum) {
                pomp(1,$1->val);
            }
            else{
                if($1->array) {
                    if($1->varOffset == NULL){
                        pomp_addr(0,*$1); // pomp_addr
                        //pomp(0,$1->addr + $1->offset);
                    }
                    else
                    {
                        /* zablokowane przez dodawanie */
                    }
                }
                else
                    pomp_addr(0,*$1); // pomp_addr
                std :: cout << "LOAD" << " 1" << std :: endl;
            }
    }
	| value '+' value  {
            printf("[BISON]ADD\n");
            std :: cout << $1->name << " + " << $3->name << std :: endl;
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
            }
                // stala i stala
            if($1->isNum && $3->isNum){
                    pomp(2, $1->val + $3->val);
            }
            else{
                // zmienna i stala
                if(!$1->isNum && $3->isNum){
                    pomp_addr(0,*$1); //R0 = a.addr;
                    pomp(1,$3->val); // R1 = b;
                    std :: cout << "ADD 1" << std :: endl; //R1 = memRO + b = a + b
                }
                // stala i zmienna
                if($1->isNum && !$3->isNum){
                    pomp_addr(0,*$3); //R0 = b.addr;
                    pomp(1,$1->val); // R1 = memRO + a = b + a;
                    std :: cout << "ADD 1" << std :: endl; //R2 = a + b
                }
                // dwie zmienne
                if(!$1->isNum && !$3->isNum){
                    pomp_addr(0,*$1); //R0 = a.addr;
                    std :: cout << "LOAD 1" << std :: endl; // R1 = a;
                    pomp_addr(0,*$3); // R0 = b.addr;
                    std :: cout << "ADD 1" << std :: endl; //R2 = a + memR0 = a + b
                }
            }
    }
	| value '-' value  {
            printf("[BISON]SUB\n");
            std :: cout << $1->name << " - " << $3->name << std :: endl;
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
            }
            // stala i stala
        if($1->isNum && $3->isNum)
            if($3->val > $1->val)
                pomp(2,0);
            else
                pomp(2, MAX(0,$1->val - $3->val));
        else{
            // zmienna i stala
            if(!$1->isNum && $3->isNum){
                pomp_addr(0,*$1); //R0 = a.addr;
                std :: cout << "LOAD 1" << std :: endl; // R2 = a;
                pomp(2,$3->val); // R0 = b;
                pomp(0,address + 1);
                std :: cout << "STORE 2" << std :: endl;
                std :: cout << "SUB 1" << std :: endl; //R2 = a + b
            }
            // stala i zmienna
            if($1->isNum && !$3->isNum){
                pomp_addr(0,*$3); //R0 = a.addr;
                pomp(1,$1->val); // R0 = b;
                std :: cout << "SUB 1" << std :: endl; //R2 = a + b
            }
            // dwie stale
            if(!$1->isNum && !$3->isNum){
                pomp_addr(0,*$1); //R0 = a.addr;
                std :: cout << "LOAD 1" << std :: endl; // R2 = a;
                pomp_addr(0,*$3); // R0 = b.addr;
                std :: cout << "SUB 1" << std :: endl; //R2 = a + memR0 = a + b
            }
        }
    }
	| value '*' value  { // Wedlug mnie powinno dzialac. To obmyslilem w nocy
        printf("[BISON]MULTI\n");
        std :: cout << $1->name << " * " << $3->name << std :: endl;
        if(!$1->isNum){
        auto it = variables[$1->name];
        if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
        }

        // Czysty assembler
        if($1->isNum)
            pomp(1,$1->val); //a
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 1" << std :: endl;
        }
        if($3->isNum){
            pomp(2,$3->val); //a
            pomp(3,$3->val); //a
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 2" << std :: endl;
            std :: cout << "LOAD 3" << std :: endl;
        }


//////////  while a > 1

        //  nieparzyste to ET1
        std :: cout << "JODD 3 ET" << label++ << std :: endl;
        //  parzyste to ET2
        std :: cout << "JUMP ET" << label++ << std :: endl;
//////////  ET1 -  a % 2 = 1
        std :: cout << "COPY 1" << std :: endl; // czym sie rozni Pr0 od R0 - COPY R2 czy STORE R2
        std :: cout << "ADD 4" << std :: endl; // tutaj sumujemy wolne wyrazy
        std :: cout << "DEC 2" << std :: endl; // zmniejszamy mnoznik o 1 wiec juz jest parzysy
        std :: cout << "SHR 2" << std :: endl;
        std :: cout << "SHL 1" << std :: endl;
        //  krok while a = a - 1
        std :: cout << "DEC 3" << std :: endl;
//////////  koniec ifa w ktorym mamy nieparzysty mnoznik

//////////  ET2 warunek ifa z parzystym mnoznikiem
        std :: cout << "SHR 2" << std :: endl;
        std :: cout << "SHL 1" << std :: endl;
        std :: cout << "SHR 2" << std :: endl;
        //  krok while a = a/2
        std :: cout << "SHR 3" << std :: endl;
/////////   koniec ifa parzystego
        std :: cout << "JZERO 3 ET" << label-2 << std :: endl;
/////////   koniec while


/////////  ET3 - END Dodaj wszystkie czynniki wolne ktore sumowalismy w ELSE
        std :: cout << "COPY 4" << std :: endl;
        std :: cout << "ADD 2" << std :: endl;
////////   Wynik w R2 - bo nie bylem pewien z konwencja gdzie go wrzucic.

    }
	| value '/' value  {
        printf("[BISON]DIV\n");
        std :: cout << $1->name << " / " << $3->name << std :: endl;
        if(!$1->isNum){
        auto it = variables[$1->name];
        if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                exit(1);
            }
        }
        if(!$3->isNum){
            auto it = variables[$3->name];
            if (!it.init)
            {
                std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                exit(1);
            }
        }
        // Czysty assembler
        if($1->isNum)
            pomp(1,$1->val); //a
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 1" << std :: endl;
        }
        if($3->isNum){
            pomp(2,$3->val); //b
            pomp(3,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 2" << std :: endl;
            std :: cout << "LOAD 3" << std :: endl;
        }

        //  Zaladowane wiec dzielimy












    }
	| value '%' value  {
        printf("[BISON]MOD\n");
        std :: cout << $1->name << " %% " << $3->name << std :: endl;
            if(!$1->isNum){
            auto it = variables[$1->name];
            if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $1->name << std :: endl;
                    exit(1);
                }
            }
            if(!$3->isNum){
                auto it = variables[$3->name];
                if (!it.init)
                {
                    std :: cerr << "VARIABLE NOT INITIALIZED\t" << $3->name << std :: endl;
                    exit(1);
                }
            }
            // Czysty assembler
            if($1->isNum)
                pomp(1,$1->val); //a
            else{
                pomp_addr(0,*$1);
                std :: cout << "LOAD 1" << std :: endl;
            }
            if($3->isNum){
                pomp(2,$3->val); //b
                pomp(3,$3->val); //b
            }
            else{
                pomp_addr(0,*$3);
                std :: cout << "LOAD 2" << std :: endl;
                std :: cout << "LOAD 3" << std :: endl;
            }

            //  Zaladowane wiec dzielimy















    }
;

    // W R0 lub w R1 bedzie wynik 1 - true, 0 - false
cond:
	value '=' value       { printf("[BISON]EQUAL\n");

        // Napomuj R2 = a, R3 = a, R4 = b
        if($1->isNum){
            pomp(2,$1->val); //a
            pomp(3,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 2" << std :: endl;
            std :: cout << "LOAD 3" << std :: endl;
        }
        if($3->isNum){
            pomp(4,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 4" << std :: endl;
        }

        //Czy b <= a
        std :: cout << "COPY" << " 4" << std :: endl;       // b-> R0
        std :: cout << "SUB" << " 2" << std :: endl;        // R2 = a - b
        std :: cout << "JZERO 2" << " ET" << label++ << std :: endl; // jezeli R2 == 0 to skocz do ET1
        std :: cout << "JUMP ET" << label++ << std :: endl; //  skocz do ET2 - FALSE

        // ET1 - pierwszy warunek spelniony - teraz drugi warunek
        //CZY b - a == 0 ??
        std :: cout << "COPY" << " 2" << std :: endl;// b-> R0
        std :: cout << "SUB" << " 3" << std :: endl;// R3 = b - a
        std :: cout << "JZERO 3" << " ET" << label++ << std :: endl; // jezeli R3 == 0 to skocz do ET3 czyli rownosc spelniona
        std :: cout << "JUMP ET" << label-- << std :: endl; //  // ma skoczyc do 2 a nie do 3 wiec label--


        // ET2 - nie spelnione - wrzuc wartosc do R0 - false i skocz do etykiety ET3
        //a > b lub b > a
        std :: cout << "JUMP ET" << label++ << std :: endl;

        //ET3 - END
        std :: cout << "HALT"  << std :: endl;


  }
	| value NE value
    {
        printf("[BISON]NE\n");
        // W R0 lub w R1 bedzie wynik 1 - true, 0 - false
        // Napomuj R2 = a, R3 = a, R4 = b
        if($1->isNum){
            pomp(2,$1->val); //a
            pomp(3,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 2" << std :: endl;
            std :: cout << "LOAD 3" << std :: endl;
        }
        if($3->isNum){
            pomp(4,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 4" << std :: endl;
        }

        //Czy b => a
        std :: cout << "COPY" << " 4" << std :: endl;       // b-> R0
        std :: cout << "SUB" << " 2" << std :: endl;        // R2 = a - b
        std :: cout << "JZERO 2" << " ET" << label++ << std :: endl; // b > a lub b == a
        label += 2;
        std :: cout << "JUMP ET" << label << std :: endl; //  a-b > 0 to mamy nierownosc wiec skocz do ET3 - TRUE

        // ET1 wiec b >= a
        //CZY a == b?
        std :: cout << "COPY" << " 2" << std :: endl;// a-> R0
        std :: cout << "SUB" << " 3" << std :: endl;// R3 = b - a
        std :: cout << "JZERO 3" << " ET" << label--  << std :: endl; // jezeli R3 == 0 to skocz do ET2 bo FALSE
        std :: cout << "JUMP ET" << label++ << std :: endl; //  skaczemy do ET3 - mamy nierownosc

        //ET2
        std :: cout << "JUMP ET" << label << std :: endl;

        //ET3 - END
        std :: cout << "HALT"  << std :: endl;
    }
	| value '<' value
    {
        // a < b lub a + 1 <= b
        printf("[BISON]LT\n");
        //R2 = a R3 = b
        if($1->isNum){
            pomp(2,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 2" << std :: endl;
        }
        if($3->isNum){
            pomp(3,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 3" << std :: endl;
        }
        std :: cout << "COPY 3" << std :: endl;     //R0 = b
        std :: cout << "INC 2" << std :: endl;
        std :: cout << "SUB 2" << std :: endl;      //R2 = a + 1 - b = R2 - memR0 = 0
        std :: cout << "JZERO 2 ET" << label ++ << std :: endl;      //Jezeli R2 == 0 to mamy spelniony warunek
        std :: cout << "JUMP ET" << label++ << std :: endl;         // Jezeli nie to skocz do ET2 - false

        //ET1 - TRUE
        std :: cout << "JUMP ET" << label++ << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET2 - FALSE
        std :: cout << "JUMP ET" << label << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET3 -  END
        std :: cout << "HALT" << std :: endl;

    }
	| value '>' value
    {
        // a > b lub a >= b + 1
        printf("[BISON]GT\n");
        if($1->isNum){
            pomp(2,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 2" << std :: endl;
        }
        if($3->isNum){
            pomp(3,$3->val); //b
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 3" << std :: endl;
        }
        // a >= b
        // W R0 lub w R1 bedzie wynik 1 - true, 0 - false
        std :: cout << "COPY 2" << std :: endl; //R0 = a
        std :: cout << "INC 3" << std :: endl; //R3 = b + 1
        std :: cout << "SUB 3" << std :: endl;  //R3 = b + 1 - a = R3 - memR0 = 0
        std :: cout << "JZERO 3 ET" << label++ << std :: endl;//Jezeli R3 == 0 to mamy
        std :: cout << "JUMP ET" << label++ << std :: endl;//Jezeli nie to END FALSE

        //ET1 - TRUE
        std :: cout << "JUMP ET" << label++ << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET2 - FALSE
        std :: cout << "JUMP ET" << label << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET3 -  END
        std :: cout << "HALT" << std :: endl;

    }
	| value LE value
    {
        // a <= b
        printf("[BISON]LE\n");
        if($1->isNum){
            pomp(2,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 2" << std :: endl;
        }
        if($3->isNum){
            pomp(3,$3->val); //a
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 3" << std :: endl;
        }
        std :: cout << "COPY 3" << std :: endl;     //R0 = b
        std :: cout << "SUB 2" << std :: endl;      //R2 = a - b = R2 - memR0
        std :: cout << "JZERO 2 ET" << label++ << std :: endl;      //Jezeli R2 == 0 to mamy spelniony warunek
        std :: cout << "JUMP ET" << label++ << std :: endl;         // Jezeli nie to skocz do ET2 - false

        //ET1 - TRUE
        std :: cout << "INC 0"  << std :: endl;
        std :: cout << "JUMP ET" << label++ << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET2 - FALSE
        std :: cout << "ZERO 0" << std :: endl;     // Nie zwiekszamy etykiety bo zostala zwiekszona do 3 w TRUE
        std :: cout << "JUMP ET" << label << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET3 -  END
        std :: cout << "HALT" << std :: endl;

    }
	| value GE value
    {

        printf("[BISON]GE\n");
        if($1->isNum){
            pomp(2,$1->val); //a
        }
        else{
            pomp_addr(0,*$1);
            std :: cout << "LOAD 2" << std :: endl;
        }
        if($3->isNum){
            pomp(3,$3->val); //a
        }
        else{
            pomp_addr(0,*$3);
            std :: cout << "LOAD 3" << std :: endl;
        }
        // a >= b
        // W R0 lub w R1 bedzie wynik 1 - true, 0 - false
        std :: cout << "COPY 2" << std :: endl; //R0 = a
        std :: cout << "SUB 3" << std :: endl;  //R3 = b - a = R3 - memR0
        std :: cout << "JZERO 3 ET" << label++ << std :: endl;//Jezeli R3 == 0 to mamy
        std :: cout << "JUMP ET" << label++ << std :: endl;//Jezeli nie to END FALSE

        //ET1 - TRUE
        std :: cout << "INC 0"  << std :: endl;
        std :: cout << "JUMP ET" << label++ << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET2 - FALSE
        std :: cout << "ZERO 0" << std :: endl;     // Nie zwiekszamy etykiety bo zostala zwiekszona do 3 w TRUE
        std :: cout << "JUMP ET" << label << std :: endl;         // Zakoncz - skocz do etykiety ET3

        //ET3 -  END
        std :: cout << "HALT" << std :: endl;

    }
;

value:
	NUM
    {
        $$ = new Variable;
        $$->name = $1.str;
        $$->isNum = true;
        $$->val = atoll($1.str);
    }
	| identifier
    {
        $$ = $1;
    }
;

identifier:
	VARIABLE
    {
        /* czy DECLARED  */
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }
        /* czy ARRAY  */
        Variable var = variables[std  :: string($1.str)];
        if( var.array){
            std :: cerr << "VARIABLE IS ARRAY" << $1.str << std :: endl;
            exit(1);
        }
        /* czy Propagacja  */
        $$ = new Variable;
        variable_copy(*$$, var);
    }
	| VARIABLE '[' VARIABLE ']'
    {

        /* czy DECLARED  */
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }
        /* czy ARRAY  */
        Variable var = variables[std  :: string($1.str)];
        if( !var.array){
            std :: cerr << "VARIABLE ISNT ARRAY" << $1.str << std :: endl;
            exit(1);
        }

        /* czy DECLARED  */
        it = variables.find(std :: string($3.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $3.str << std :: endl;
            exit(1);
        }

        /* czy NIE ARRAY  */
        var = variables[std  :: string($3.str)];
        if( var.array){
            std :: cerr << "VARIABLE CANT BE ARRAY" << $3.str << std :: endl;
            exit(1);
        }


        var = variables[std  :: string($1.str)];
        Variable var2 = variables[std  :: string($3.str)];


        /* czy Propagacja  */
        Variable *varptr1 = new Variable;
        variable_copy(*varptr1, var);
        Variable *varptr2 = new Variable;
        variable_copy(*varptr2, var2);
        varptr1->varOffset = varptr2;
        $$ = new Variable;
        variable_copy(*$$, *varptr1);
    }
	| VARIABLE '[' NUM ']'
    {
        /* czy DECLARED  */
        auto it = variables.find(std :: string($1.str));
        if (it == variables.end())
        {
            std :: cerr << "NOT DECLARED\t" << $1.str << std :: endl;
            exit(1);
        }

        /* czy ARRAY  */
        Variable var = variables[std  :: string($1.str)];
        if( !var.array){
            std :: cerr << "VARIABLE ISNT ARRAY\t" << $1.str << std :: endl;
            exit(1);
        }
            /* czy OUT OF RANGE  */
        if( var.len <= atoll($3.str)){
            std :: cerr << "OUT OF RANGE\t" << $1.str << std :: endl;
            exit(1);
        }

            /* Propagacja  */
        $$ = new Variable;
        variable_copy(*$$, var);
        $$->varOffset = NULL;
        $$->offset = atoll($3.str);

    }
;

%%
void yyerror(const char *msg)
{
    printf("ERROR!!!\t%s\t%s\nLINE\t%d\n",msg,yylval.token.str, yylval.token.line);
    exit(1);
}

inline void variable_copy(Variable &dst, Variable const &src)
{
        dst.name = src.name;
        dst.reg = src.reg;
        dst.addr = src.addr;
        dst.len = src.len;
        dst.isNum = src.isNum;
        dst.upToDate = src.upToDate;
        dst.array = src.array;
        dst.init = src.init;
        dst.iter = src.iter;
        dst.val = src.val;
        dst.offset = src.offset;
        dst.varOffset = src.varOffset;
}

inline void pomp(int numRegister, uint64_t val)
{
    int i;

    std :: cout << "ZERO " << numRegister << std :: endl;

    for(i = (sizeof(uint64_t) * 8) - 1; i > 0; --i)
        if(GET_BIT(val , i) )
            break;

    for(; i > 0; --i)
        if( GET_BIT(val , i) )
        {
            std :: cout << "INC " << numRegister << std :: endl;
            std :: cout << "SHL " << numRegister << std :: endl;
        }
        else
        {
            std :: cout << "SHL " << numRegister << std :: endl;
        }

    if(GET_BIT(val, i))
        std :: cout << "INC " << numRegister << std :: endl;
}

inline void pomp_addr(int numRegister,Variable const &var){
    if(!var.array)
        pomp(numRegister, var.addr);
    else
        if ( var.var_offset == NULL )
            pomp(numRegister, var.addr + var.offset);
        else{
            pomp(1,var.addr);
            pomp(0,var.var_offset.addr); // has no member named var_offset
            std :: cout << "ADD 1" << std :: endl;
            std :: cout << "COPY 0"  << std :: endl;
        }
}


inline void pompBigValue(int numRegister,cln :: cl_I value){
    int i;

    std :: cout << "ZERO " << numRegister << std :: endl;

    for(i = (sizeof(cln :: cl_I) * 8) - 1; i > 0; --i)
        if(GET_BIT(value , i) )
            break;

    for(; i > 0; --i)
        if( GET_BIT(value , i) )
        {
            std :: cout << "INC " << numRegister << std :: endl;
            std :: cout << "SHL " << numRegister << std :: endl;
        }
        else
        {
            std :: cout << "SHL " << numRegister << std :: endl;
        }

    if(GET_BIT(value, i))
        std :: cout << "INC " << numRegister << std :: endl;
}
