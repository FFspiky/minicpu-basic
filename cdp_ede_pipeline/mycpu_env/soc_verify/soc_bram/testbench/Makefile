.PHONY: clean
IVERILOG_DIR = project/loongson.sim/sim_1/behav/iverilog
MYCPU_SRC = $(wildcard ../../../myCPU/*.v)
iverilog : $(IVERILOG_DIR)/gettrace
	cd $(IVERILOG_DIR) && vvp ./gettrace

$(IVERILOG_DIR)/gettrace:
	mkdir -p $(IVERILOG_DIR) && iverilog -Wall -o $(IVERILOG_DIR)/gettrace $(MYCPU_SRC) ../rtl/*.v ../rtl/*/*.v mycpu_tb.v -I ../../../myCPU/

clean : 
	rm -rf ./project 
