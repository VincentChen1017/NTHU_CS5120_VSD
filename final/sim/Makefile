# add your source code
SIM_SRC = sim_rtl.f
SYN_SRC = sim_gate.f
BAK = *.bak
LOG = *.log *.history *.key *.vcd out_log.txt novas.rc novas.conf *.sdf.X
INCA_libs = INCA_libs
cad_dir = spyglass-* nWaveLog* BSSLib.lib*

all :: sim

sim:
	vcs -f ${SIM_SRC} -full64 +v2k -R -debug_pp -LDFLAGS -rdynamic -P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a
syn:
	vcs -f ${SYN_SRC} -full64 +v2k -R -debug_pp -LDFLAGS -rdynamic -P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a

clean:
	-rm -f ${BAK} ${LOG}
	-rm -rf ${INCA_libs} ${cad_dir}
