CXX = g++
CXXFLAGS = -std=c++11 -Wall -pedantic -O3
LEX = flex
YAC = bison

IDIR = ./include
ODIR = ./obj
SDIR = ./src

EXEC = compiler.out
SRCS = $(wildcard $(SDIR)/*.cpp)
OBJS = $(SRCS:$(SDIR)/%.cpp=$(ODIR)/%.o)
DEPS = $(wildcard $(IDIR)/*.h)

all: compiler
compiler: $(EXEC)

# Create YAC files
$(ODIR)/parser.tab.c $(IDIR)/parser.tab.h: $(SDIR)/parser.y
	$(YAC) --defines=$(IDIR)/parser.tab.h $(SDIR)/parser.y -o $(ODIR)/parser.tab.c

# Create LEX files
$(ODIR)/parser_lex.yy.c: $(SDIR)/parser.l $(IDIR)/parser.tab.h
	$(LEX) -o $@ $(SDIR)/parser.l

# To obtain object files#
$(ODIR)/%.o: $(SDIR)/%.cpp $(DEPS)
	$(CXX) $(CXXFLAGS) -c $< -o $@ -I$(IDIR)

# Compile and link all together
$(EXEC): $(ODIR)/parser_lex.yy.c $(ODIR)/parser.tab.c $(IDIR)/parser.tab.h $(OBJS)
	$(CXX) $(CXXFLAGS) -D_GNU_SOURCE -I$(IDIR) $(ODIR)/parser.tab.c $(ODIR)/parser_lex.yy.c $(OBJS) -lcln -lfl -o $@


clean:
	rm -rf $(ODIR)/*
	rm -rf $(IDIR)/parser.tab.h
	rm -f $(EXEC)
