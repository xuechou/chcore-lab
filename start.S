[1mdiff --git a/.gdbinit b/.gdbinit[m
[1mindex 598decb..98f1327 100644[m
[1m--- a/.gdbinit[m
[1m+++ b/.gdbinit[m
[36m@@ -13,4 +13,4 @@[m [mdefine add-symbol-file-auto[m
 end[m
 [m
 add-symbol-file-auto ./build/kernel.img[m
[31m-add-symbol-file-auto ./user/build/ramdisk/hello.bin[m
[32m+[m[32madd-symbol-file-auto ./user/build/ramdisk/testpf.bin[m
[1mdiff --git a/CMakeLists.txt b/CMakeLists.txt[m
[1mindex adc2b48..483fd25 100644[m
[1m--- a/CMakeLists.txt[m
[1m+++ b/CMakeLists.txt[m
[36m@@ -2,7 +2,7 @@[m [mcmake_minimum_required (VERSION 3.14)[m
 [m
 set(CMAKE_VERBOSE_MAKEFILE on)[m
 [m
[31m-set(CMAKE_BUILD_TYPE "Release")  # "Release" or "Debug"[m
[32m+[m[32mset(CMAKE_BUILD_TYPE "Debug")  # "Release" or "Debug"[m
 set(CHCORE_PLAT "raspi3")[m
 set(CHCORE_ARCH "aarch64")[m
 [m
[36m@@ -46,6 +46,8 @@[m [mset(KERNEL_SYSCALL_PATH     "${KERNEL_PATH}/syscall")[m
 set(KERNEL_EXCEPTION_PATH   "${KERNEL_PATH}/exception")[m
 set(KERNEL_PROCESS_PATH     "${KERNEL_PATH}/process")[m
 set(KERNEL_SCHED_PATH       "${KERNEL_PATH}/sched")[m
[32m+[m[32mset(KERNEL_IPC_PATH         "${KERNEL_PATH}/ipc")[m
[32m+[m[32mset(KERNEL_TESTS_PATH       "${KERNEL_PATH}/tests")[m
 [m
 include_directories(".")[m
 include_directories("${KERNEL_PATH}")[m
[36m@@ -56,6 +58,8 @@[m [madd_subdirectory("${KERNEL_PROCESS_PATH}")[m
 add_subdirectory("${KERNEL_SYSCALL_PATH}")[m
 add_subdirectory("${KERNEL_EXCEPTION_PATH}")[m
 add_subdirectory("${KERNEL_SCHED_PATH}")[m
[32m+[m[32madd_subdirectory("${KERNEL_IPC_PATH}")[m
[32m+[m[32madd_subdirectory("${KERNEL_TESTS_PATH}")[m
 [m
 set(BINARY_KERNEL_IMG_PATH "CMakeFiles/kernel.img.dir")[m
 set(init_object[m
[36m@@ -79,6 +83,8 @@[m [madd_executable(kernel.img ${files}[m
     $<TARGET_OBJECTS:${PROJECT_NAME}-syscall>[m
     $<TARGET_OBJECTS:${PROJECT_NAME}-sched>[m
     $<TARGET_OBJECTS:${PROJECT_NAME}-exception>[m
[32m+[m[32m    $<TARGET_OBJECTS:${PROJECT_NAME}-ipc>[m
[32m+[m[32m    $<TARGET_OBJECTS:${PROJECT_NAME}-tests>[m
     ${USER_PATH}/binary_include.S[m
 )[m
 [m
[1mdiff --git a/Makefile b/Makefile[m
[1mindex 9492ded..e6f393d 100644[m
[1m--- a/Makefile[m
[1m+++ b/Makefile[m
[36m@@ -3,7 +3,7 @@[m [mifndef QEMU[m
 QEMU := qemu-system-aarch64[m
 endif[m
 [m
[31m-LAB := 3[m
[32m+[m[32mLAB := 4[m
 # try to generate a unique GDB port[m
 GDBPORT	:= 1234[m
 QEMUOPTS = -machine raspi3 -serial null -serial mon:stdio -m size=1G -kernel $(BUILD_DIR)/kernel.img -gdb tcp::1234[m
[1mdiff --git a/boot/boot.h b/boot/boot.h[m
[1mindex 7e7452f..4c991b2 100644[m
[1m--- a/boot/boot.h[m
[1m+++ b/boot/boot.h[m
[36m@@ -4,6 +4,7 @@[m [mextern void el1_mmu_activate(void);[m
 extern void init_boot_pt(void);[m
 [m
 extern void start_kernel(void *boot_flag);[m
[32m+[m[32mextern void secondary_cpu_boot(int cpuid);[m
 [m
 extern char _bss_start;[m
 extern char _bss_end;[m
[1mdiff --git a/boot/init_c.c b/boot/init_c.c[m
[1mindex 43d5636..a069721 100644[m
[1m--- a/boot/init_c.c[m
[1m+++ b/boot/init_c.c[m
[36m@@ -24,6 +24,30 @@[m [mvolatile u64 clear_bss_flag = NOT_BSS;[m
 void early_uart_init(void);[m
 void uart_send_string(char *);[m
 [m
[32m+[m[32mstatic void wakeup_other_cores(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 *addr;[m
[32m+[m
[32m+[m	[32m/*[m
[32m+[m	[32m * Set the entry address for non-primary cores.[m
[32m+[m	[32m * 0xe0, 0xe8, 0xf0 are fixed in the firmware (armstub8.bin).[m
[32m+[m	[32m */[m
[32m+[m	[32m// addr = (u64 *)0xd8;[m
[32m+[m	[32m// *addr = TEXT_OFFSET;[m
[32m+[m	[32maddr = (u64 *) 0xe0;[m
[32m+[m	[32m*addr = TEXT_OFFSET;[m
[32m+[m	[32maddr = (u64 *) 0xe8;[m
[32m+[m	[32m*addr = TEXT_OFFSET;[m
[32m+[m	[32maddr = (u64 *) 0xf0;[m
[32m+[m	[32m*addr = TEXT_OFFSET;[m
[32m+[m
[32m+[m	[32m/*[m
[32m+[m	[32m * Instruction sev (set event) for waking up other (non-primary) cores[m
[32m+[m	[32m * that executes wfe instruction.[m
[32m+[m	[32m */[m
[32m+[m	[32masm volatile ("sev");[m
[32m+[m[32m}[m
[32m+[m
 static void clear_bss(void)[m
 {[m
 	u64 bss_start_addr;[m
[36m@@ -48,6 +72,8 @@[m [mvoid init_c(void)[m
 	early_uart_init();[m
 	uart_send_string("boot: init_c\r\n");[m
 [m
[32m+[m	[32mwakeup_other_cores();[m
[32m+[m
 	/* Initialize Boot Page Table. */[m
 	uart_send_string("[BOOT] Install boot page table\r\n");[m
 	init_boot_pt();[m
[36m@@ -62,3 +88,9 @@[m [mvoid init_c(void)[m
 [m
 	/* Never reach here */[m
 }[m
[32m+[m
[32m+[m[32mvoid secondary_init_c(int cpuid)[m
[32m+[m[32m{[m
[32m+[m	[32mel1_mmu_activate();[m
[32m+[m	[32msecondary_cpu_boot(cpuid);[m
[32m+[m[32m}[m
[1mdiff --git a/boot/start.S b/boot/start.S[m
[1mindex b330fa5..4820afb 100644[m
[1m--- a/boot/start.S[m
[1m+++ b/boot/start.S[m
[36m@@ -3,6 +3,7 @@[m
 .extern arm64_elX_to_el1[m
 .extern boot_cpu_stack[m
 .extern secondary_boot_flag[m
[32m+[m[32m.extern secondary_init_c[m
 .extern clear_bss_flag[m
 .extern init_c[m
 [m
[36m@@ -11,9 +12,36 @@[m [mBEGIN_FUNC(_start)[m
 	and	x8, x8,	#0xFF[m
 	cbz	x8, primary[m
 [m
[31m-  /* hang all secondary processors before we intorduce multi-processors */[m
[31m-secondary_hang:[m
[31m-	bl secondary_hang[m
[32m+[m	[32m/* Wait for bss clear */[m
[32m+[m[32mwait_for_bss_clear:[m
[32m+[m	[32madr	x0, clear_bss_flag[m
[32m+[m	[32mldr	x1, [x0][m
[32m+[m	[32mcmp     x1, #0[m
[32m+[m	[32mbne	wait_for_bss_clear[m
[32m+[m
[32m+[m	[32m/* Turn to el1 from other exception levels. */[m
[32m+[m	[32mbl 	arm64_elX_to_el1[m
[32m+[m
[32m+[m	[32m/* Prepare stack pointer and jump to C. */[m
[32m+[m	[32mmov	x1, #0x1000[m
[32m+[m	[32mmul	x1, x8, x1[m
[32m+[m	[32madr 	x0, boot_cpu_stack[m
[32m+[m	[32madd	x0, x0, x1[m
[32m+[m	[32madd	x0, x0, #0x1000[m
[32m+[m[32m        mov	sp, x0[m
[32m+[m
[32m+[m[32mwait_until_smp_enabled:[m
[32m+[m	[32m/* CPU ID should be stored in x8 from the first line */[m
[32m+[m	[32mmov	x1, #8[m
[32m+[m	[32mmul	x2, x8, x1[m
[32m+[m	[32mldr	x1, =secondary_boot_flag[m
[32m+[m	[32madd	x1, x1, x2[m
[32m+[m	[32mldr	x3, [x1][m
[32m+[m	[32mcbz	x3, wait_until_smp_enabled[m
[32m+[m
[32m+[m	[32m/* Set CPU id */[m
[32m+[m	[32mmov	x0, x8[m
[32m+[m	[32mbl 	secondary_init_c[m
 [m
 primary:[m
 [m
[1mdiff --git a/kernel/CMakeLists.txt b/kernel/CMakeLists.txt[m
[1mindex de068ec..aa89daa 100644[m
[1m--- a/kernel/CMakeLists.txt[m
[1m+++ b/kernel/CMakeLists.txt[m
[36m@@ -5,9 +5,12 @@[m [madd_library(${PROJECT_NAME}-arch process[m
     main.c[m
     monitor.c[m
     common/tools.S[m
[32m+[m[32m    common/smp.c[m
     common/cpio.c[m
     common/elf.c[m
     common/uart.c[m
[32m+[m[32m    common/lock.c[m
     common/printk.c[m
[32m+[m[32m    common/fs.c[m
     common/radix.c[m
 )[m
[1mdiff --git a/kernel/common/fs.c b/kernel/common/fs.c[m
[1mnew file mode 100644[m
[1mindex 0000000..e5150ea[m
[1m--- /dev/null[m
[1m+++ b/kernel/common/fs.c[m
[36m@@ -0,0 +1,49 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m[32m#include <common/fs.h>[m
[32m+[m[32m#include <process/capability.h>[m
[32m+[m[32m#include <process/process.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <common/uaccess.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <common/mm.h>[m
[32m+[m[32m#include <mm/vmspace.h>[m
[32m+[m
[32m+[m[32mint sys_fs_load_cpio(u64 vaddr)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct pmobject *cpio_pmo;[m
[32m+[m	[32mstruct vmspace *vmspace;[m
[32m+[m	[32mint cpio_pmo_cap, ret;[m
[32m+[m	[32msize_t len;[m
[32m+[m
[32m+[m	[32mcpio_pmo = obj_alloc(TYPE_PMO, sizeof(*cpio_pmo));[m
[32m+[m	[32mif (!cpio_pmo) {[m
[32m+[m		[32mreturn -ENOMEM;[m
[32m+[m	[32m}[m
[32m+[m	[32mlen = ROUND_UP(binary_cpio_bin_size, PAGE_SIZE);[m
[32m+[m	[32mpmo_init(cpio_pmo, PMO_DATA, len, 0);[m
[32m+[m
[32m+[m	[32mcpio_pmo_cap = cap_alloc(current_process, cpio_pmo, 0);[m
[32m+[m	[32mif (cpio_pmo_cap < 0) {[m
[32m+[m		[32mobj_free(cpio_pmo);[m
[32m+[m		[32mreturn -ENOMEM;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mvmspace = obj_get(current_process, VMSPACE_OBJ_ID, TYPE_VMSPACE);[m
[32m+[m
[32m+[m	[32mret = vmspace_map_range(vmspace, vaddr, len, VMR_READ, cpio_pmo);[m
[32m+[m	[32mmemcpy((void *)phys_to_virt(cpio_pmo->start),[m
[32m+[m	[32m       &binary_cpio_bin_start, binary_cpio_bin_size);[m
[32m+[m
[32m+[m	[32mobj_put(vmspace);[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/common/fs.h b/kernel/common/fs.h[m
[1mnew file mode 100644[m
[1mindex 0000000..192b9e4[m
[1m--- /dev/null[m
[1m+++ b/kernel/common/fs.h[m
[36m@@ -0,0 +1,21 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m
[32m+[m[32m/* RAMDISK symbol */[m
[32m+[m[32mextern const char binary_cpio_bin_start;[m
[32m+[m[32mextern size_t binary_cpio_bin_size;[m
[32m+[m
[32m+[m[32mint sys_fs_load_cpio(u64 vaddr);[m
[1mdiff --git a/kernel/common/lock.c b/kernel/common/lock.c[m
[1mnew file mode 100644[m
[1mindex 0000000..93a770a[m
[1m--- /dev/null[m
[1m+++ b/kernel/common/lock.c[m
[36m@@ -0,0 +1,129 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/sync.h>[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/lock.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m
[32m+[m[32mstruct lock big_kernel_lock;[m
[32m+[m
[32m+[m[32mint lock_init(struct lock *lock)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(!lock);[m
[32m+[m	[32m/* Initialize ticket lock */[m
[32m+[m	[32mlock->owner = 0;[m
[32m+[m	[32mlock->next = 0;[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Lock the ticket lock[m
[32m+[m[32m * This function will block until the lock is held[m
[32m+[m[32m*/[m
[32m+[m[32mvoid lock(struct lock *lock)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 lockval = 0, newval = 0, ret = 0;[m
[32m+[m
[32m+[m	[32mBUG_ON(!lock);[m
[32m+[m
[32m+[m	[32m/**[m[41m [m
[32m+[m	[32m * The following asm code means:[m
[32m+[m	[32m *[m[41m [m
[32m+[m	[32m * lock->next = fetch_and_add(1);[m
[32m+[m	[32m * while(lock->next != lock->owner);[m
[32m+[m	[32m */[m
[32m+[m	[32masm volatile ("       prfm    pstl1strm, %3\n"[m
[32m+[m		[32m      "1:     ldaxr   %w0, %3\n"[m
[32m+[m		[32m      "       add     %w1, %w0, #0x1\n"[m
[32m+[m		[32m      "       stxr    %w2, %w1, %3\n"[m
[32m+[m		[32m      "       cbnz    %w2, 1b\n"[m
[32m+[m		[32m      "2:     ldar    %w2, %4\n"[m
[32m+[m		[32m      "       cmp     %w0, %w2\n"[m
[32m+[m		[32m      "       b.ne    2b\n":"=&r" (lockval), "=&r"(newval),[m
[32m+[m		[32m      "=&r"(ret), "+Q"(lock->next)[m
[32m+[m		[32m      :"Q"(lock->owner)[m
[32m+[m		[32m      :"memory");[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Try to lock the ticket lock[m
[32m+[m[32m * Return 0 if succeed, -1 otherwise[m
[32m+[m[32m*/[m
[32m+[m[32mint try_lock(struct lock *lock)[m
[32m+[m[32m{[m
[32m+[m
[32m+[m	[32mu32 lockval = 0, newval = 0, ret = 0, ownerval = 0;[m
[32m+[m
[32m+[m	[32mBUG_ON(!lock);[m
[32m+[m	[32masm volatile ("       prfm    pstl1strm, %4\n" "       ldaxr   %w0, %4\n" "       ldar    %w3, %5\n" "       add     %w1, %w0, #0x1\n" "       cmp     %w0, %w3\n" "       b.ne    1f\n" "       stxr    %w2, %w1, %4\n" "       cbz     %w2, 2f\n" "1:     mov     %w2, #0xffffffffffffffff\n"	/* fail */[m
[32m+[m		[32m      "       b       3f\n" "2:     mov     %w2, #0x0\n"	/* success */[m
[32m+[m		[32m      "       dmb     ish\n"	/* barrier */[m
[32m+[m		[32m      "3:\n":"=&r" (lockval), "=&r"(newval), "=&r"(ret),[m
[32m+[m		[32m      "=&r"(ownerval), "+Q"(lock->next)[m
[32m+[m		[32m      :"Q"(lock->owner)[m
[32m+[m		[32m      :"memory");[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Unlock the ticket lock[m
[32m+[m[32m*/[m
[32m+[m[32mvoid unlock(struct lock *lock)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(!lock);[m
[32m+[m	[32masm volatile ("dmb ish");[m
[32m+[m
[32m+[m	[32m/**[m[41m [m
[32m+[m	[32m * Lab4[m[41m [m
[32m+[m	[32m * Unlock the ticket lock here[m
[32m+[m	[32m * Your code should be no more than 5 lines[m
[32m+[m	[32m*/[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m[41m [m
[32m+[m[32m * Lab4[m[41m [m
[32m+[m[32m * Check whether the ticket lock is locked[m
[32m+[m[32m * Return 1 if locked, 0 otherwise[m
[32m+[m[32m * Your code should be no more than 5 lines[m
[32m+[m[32m*/[m
[32m+[m[32mint is_locked(struct lock *lock)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn -1;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * 	Lab4[m[41m [m
[32m+[m[32m * 	Initialization of the big kernel lock[m
[32m+[m[32m */[m
[32m+[m[32mvoid kernel_lock_init(void)[m
[32m+[m[32m{[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * 	Lab4[m[41m [m
[32m+[m[32m * 	Acquire the big kernel lock[m
[32m+[m[32m */[m
[32m+[m[32mvoid lock_kernel(void)[m
[32m+[m[32m{[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * 	Lab4[m[41m [m
[32m+[m[32m * 	Release the big kernel lock[m
[32m+[m[32m */[m
[32m+[m[32mvoid unlock_kernel(void)[m
[32m+[m[32m{[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/common/lock.h b/kernel/common/lock.h[m
[1mnew file mode 100644[m
[1mindex 0000000..8fa8d33[m
[1m--- /dev/null[m
[1m+++ b/kernel/common/lock.h[m
[36m@@ -0,0 +1,35 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m
[32m+[m[32mstruct lock {[m
[32m+[m	[32mvolatile u32 owner;[m
[32m+[m	[32mchar pad0[pad_to_cache_line(sizeof(u32))];[m
[32m+[m
[32m+[m	[32mvolatile u32 next;[m
[32m+[m	[32mchar pad1[pad_to_cache_line(sizeof(u32))];[m
[32m+[m[32m} __attribute__ ((aligned(CACHELINE_SZ)));[m
[32m+[m
[32m+[m[32mint lock_init(struct lock *lock);[m
[32m+[m[32mvoid lock(struct lock *lock);[m
[32m+[m[32mint try_lock(struct lock *lock);[m
[32m+[m[32mvoid unlock(struct lock *lock);[m
[32m+[m[32mint is_locked(struct lock *lock);[m
[32m+[m
[32m+[m[32m/* Global locks */[m
[32m+[m[32mextern struct lock big_kernel_lock;[m
[32m+[m[32mvoid kernel_lock_init(void);[m
[32m+[m[32mvoid lock_kernel(void);[m
[32m+[m[32mvoid unlock_kernel(void);[m
[1mdiff --git a/kernel/common/mm.h b/kernel/common/mm.h[m
[1mindex 31b3b80..cb23d42 100644[m
[1m--- a/kernel/common/mm.h[m
[1m+++ b/kernel/common/mm.h[m
[36m@@ -17,10 +17,15 @@[m
 #include <common/mmu.h>[m
 [m
 #define PAGE_SIZE (0x1000)[m
[32m+[m[32m#define BLOCK_SHIFT (21)[m
[32m+[m[32m#define BLOCK_SIZE (1UL << BLOCK_SHIFT)[m
 [m
 void mm_init();[m
 void set_page_table(paddr_t pgtbl);[m
 [m
[32m+[m[32mvoid map_kernel_space(vaddr_t va, paddr_t pa, size_t len);[m
[32m+[m[32mvoid kernel_space_check(void);[m
[32m+[m
 static inline bool is_user_addr(vaddr_t vaddr)[m
 {[m
 	return vaddr < KBASE;[m
[1mdiff --git a/kernel/common/printk.c b/kernel/common/printk.c[m
[1mindex 29ebc95..52d7464 100644[m
[1m--- a/kernel/common/printk.c[m
[1m+++ b/kernel/common/printk.c[m
[36m@@ -120,6 +120,19 @@[m [mstatic int printk_write_num(char **out, long long i, int base, int sign,[m
 	// 1. the last postion of this buffer must be '\0'[m
 	// 2. the format is only decided by `base` and `letbase` here[m
 [m
[32m+[m	[32ms = print_buf + PRINT_BUF_LEN;[m
[32m+[m	[32m*s = '\0';[m
[32m+[m	[32mwhile(u){[m
[32m+[m		[32mt = u % base;[m
[32m+[m		[32mif(t < 10){ // base less than 10[m
[32m+[m			[32m*--s = '0' + t;[m
[32m+[m		[32m}else{ // e.g. hex[m[41m [m
[32m+[m			[32m*--s = letbase + (t - 10);[m
[32m+[m		[32m}[m
[32m+[m		[32mu /= base;[m
[32m+[m	[32m}[m
[32m+[m	[32m// finish todo[m
[32m+[m
 	if (neg) {[m
 		if (width && (flags & PAD_ZERO)) {[m
 			simple_outputchar(out, '-');[m
[1mdiff --git a/kernel/common/smp.c b/kernel/common/smp.c[m
[1mnew file mode 100644[m
[1mindex 0000000..17bd153[m
[1m--- /dev/null[m
[1m+++ b/kernel/common/smp.c[m
[36m@@ -0,0 +1,54 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m[32m#include <common/vars.h>[m
[32m+[m[32m#include <common/mm.h>[m
[32m+[m
[32m+[m[32mvolatile char cpu_status[PLAT_CPU_NUM] = { cpu_hang, cpu_hang, cpu_hang,[m
[32m+[m	[32mcpu_hang[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mvoid enable_smp_cores(void *addr)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mlong *secondary_boot_flag;[m
[32m+[m
[32m+[m	[32m/* Set current cpu status */[m
[32m+[m	[32mcpu_status[smp_get_cpu_id()] = cpu_run;[m
[32m+[m	[32msecondary_boot_flag = (long *)phys_to_virt(addr);[m
[32m+[m	[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m		[32m/* Lab4[m
[32m+[m		[32m * You should set one flag to enable the APs to continue in[m
[32m+[m		[32m * _start of `start.S`. Then, what's the flag?[m
[32m+[m		[32m * You only need to write one line of code.[m
[32m+[m		[32m */[m
[32m+[m
[32m+[m		[32m/* Lab4[m
[32m+[m		[32m * The BSP waits for the currently initializing AP finishing[m
[32m+[m		[32m * before activating the next one[m
[32m+[m		[32m */[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/* This information is printed when all CPUs finish their initialization */[m
[32m+[m	[32mkinfo("All %d CPUs are active\n", PLAT_CPU_NUM);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mu32 smp_get_cpu_id(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 cpuid = 0;[m
[32m+[m
[32m+[m	[32masm volatile ("mrs %0, tpidr_el1":"=r" (cpuid));[m
[32m+[m	[32mreturn (u32) cpuid;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/common/smp.h b/kernel/common/smp.h[m
[1mnew file mode 100644[m
[1mindex 0000000..0116559[m
[1m--- /dev/null[m
[1m+++ b/kernel/common/smp.h[m
[36m@@ -0,0 +1,28 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <common/vars.h>[m
[32m+[m[32m#include <common/machine.h>[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m
[32m+[m[32menum cpu_state {[m
[32m+[m	[32mcpu_hang = 0,[m
[32m+[m	[32mcpu_run = 1,[m
[32m+[m	[32mcpu_idle = 2[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mextern volatile char cpu_status[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32mvoid enable_smp_cores(void *addr);[m
[32m+[m[32mu32 smp_get_cpu_id(void);[m
[1mdiff --git a/kernel/exception/exception.c b/kernel/exception/exception.c[m
[1mindex 163f65c..9e71a40 100644[m
[1m--- a/kernel/exception/exception.c[m
[1m+++ b/kernel/exception/exception.c[m
[36m@@ -12,35 +12,56 @@[m
 [m
 #include "exception.h"[m
 #include "esr.h"[m
[32m+[m[32m#include "timer.h"[m
 #include <common/kprint.h>[m
[32m+[m[32m#include <common/lock.h>[m
[32m+[m[32m#include <common/smp.h>[m
 #include <common/types.h>[m
 #include <common/util.h>[m
 #include <exception/irq.h>[m
 #include <exception/pgfault.h>[m
 #include <sched/sched.h>[m
 [m
[32m+[m[32mu8 irq_handle_type[MAX_IRQ_NUM];[m
[32m+[m
 void exception_init_per_cpu(void)[m
 {[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m *[m
[32m+[m	[32m * Uncomment the timer_init() when you are handling preemptive[m
[32m+[m	[32m * shceduling[m
[32m+[m	[32m */[m
[32m+[m	[32m// timer_init();[m
[32m+[m
 	/**[m
 	 * Lab3: Your code here[m
 	 * Setup the exception vector with the asm function written in exception.S[m
 	 */[m
 	disable_irq();[m
[32m+[m	[32mset_exception_vector();[m
[32m+[m	[32menable_irq();[m
 }[m
 [m
 void exception_init(void)[m
 {[m
 	exception_init_per_cpu();[m
[32m+[m	[32mmemset(irq_handle_type, HANDLE_KERNEL, MAX_IRQ_NUM);[m
 }[m
 [m
 void handle_entry_c(int type, u64 esr, u64 address)[m
 {[m
[32m+[m	[32m/**[m[41m [m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Acquire the big kernel lock, if the exception is from kernel[m
[32m+[m	[32m */[m
[32m+[m
 	/* ec: exception class */[m
 	u32 esr_ec = GET_ESR_EL1_EC(esr);[m
 [m
[31m-	kdebug[m
[31m-	    ("Interrupt type: %d, ESR: 0x%lx, Fault address: 0x%lx, EC 0b%b\n",[m
[31m-	     type, esr, address, esr_ec);[m
[32m+[m	[32m// kdebug[m
[32m+[m	[32m    // ("Interrupt type: %d, ESR: 0x%lx, Fault address: 0x%lx, EC 0b%b\n",[m
[32m+[m	[32m    //  type, esr, address, esr_ec);[m
 	/* Dispatch exception according to EC */[m
 	switch (esr_ec) {[m
 		/*[m
[36m@@ -48,6 +69,20 @@[m [mvoid handle_entry_c(int type, u64 esr, u64 address)[m
 		 * Handle exceptions as required in the lab document. Checking exception codes in[m
 		 * esr.h may help.[m
 		 */[m
[32m+[m	[32mcase ESR_EL1_EC_UNKNOWN:[m
[32m+[m		[32mkinfo(UNKNOWN);[m
[32m+[m		[32msys_exit(-ESUPPORT); // in errno.h[m
[32m+[m		[32mbreak;[m
[32m+[m	[32m// case ESR_EL1_EC_IABT_LEL: //esr-ec = 0b100000[m
[32m+[m	[32m// case ESR_EL1_EC_IABT_CEL:[m
[32m+[m	[32m// 	kinfo(UNKNOWN);[m
[32m+[m	[32m// 	sys_exit(-ESUPPORT);[m
[32m+[m	[32m// 	break;[m
[32m+[m	[32mcase ESR_EL1_EC_DABT_LEL:[m
[32m+[m	[32mcase ESR_EL1_EC_DABT_CEL:[m
[32m+[m		[32mdo_page_fault(esr, address);[m
[32m+[m		[32mbreak;[m
[32m+[m
 	default:[m
 		kdebug("Unsupported Exception ESR %lx\n", esr);[m
 		break;[m
[1mdiff --git a/kernel/exception/exception_table.S b/kernel/exception/exception_table.S[m
[1mindex cb172f9..6ad47ab 100644[m
[1m--- a/kernel/exception/exception_table.S[m
[1m+++ b/kernel/exception/exception_table.S[m
[36m@@ -17,6 +17,8 @@[m
 [m
 .extern syscall_table[m
 .extern hook_syscall[m
[32m+[m[32m.extern lock_kernel[m
[32m+[m[32m.extern unlock_kernel[m
 [m
 .macro	exception_entry	label[m
 	/* Each entry should be 0x80 aligned */[m
[36m@@ -30,7 +32,7 @@[m
 	mrs	x1, esr_el1[m
 	mrs	x2, elr_el1[m
 	bl	handle_entry_c[m
[31m-	exception_exit[m
[32m+[m	[32mexception_return[m
 .endm[m
 [m
 /* See more details about the bias in registers.h */[m
[36m@@ -84,6 +86,15 @@[m
 .endm[m
 [m
 [m
[32m+[m[32m/**[m[41m 	[m
[32m+[m[32m *  Lab4[m[41m [m
[32m+[m[32m * 	unlock the big kernel lock before returning to the user mode[m
[32m+[m[32m */[m
[32m+[m[32m.macro	exception_return[m
[32m+[m	[32mexception_exit[m
[32m+[m[32m.endm[m
[32m+[m
[32m+[m
 /*[m
  * Vecotr table offsets from vector table base address from ARMv8 Manual[m
  *	Address		|	Exception Type		| 	Description[m
[36m@@ -119,6 +130,25 @@[m
  */[m
 .align	11[m
 EXPORT(el1_vector)[m
[32m+[m	[32mexception_entry sync_el1t[m
[32m+[m	[32mexception_entry irq_el1t[m
[32m+[m	[32mexception_entry fiq_el1t[m
[32m+[m	[32mexception_entry error_el1t[m
[32m+[m
[32m+[m	[32mexception_entry sync_el1h[m
[32m+[m	[32mexception_entry irq_el1h[m
[32m+[m	[32mexception_entry fiq_el1h[m
[32m+[m	[32mexception_entry error_el1h[m
[32m+[m
[32m+[m	[32mexception_entry sync_el0_64[m
[32m+[m	[32mexception_entry irq_el0_64[m
[32m+[m	[32mexception_entry fiq_el0_64[m
[32m+[m	[32mexception_entry error_el0_64[m
[32m+[m
[32m+[m	[32mexception_entry sync_el0_32[m
[32m+[m	[32mexception_entry irq_el0_32[m
[32m+[m	[32mexception_entry fiq_el0_32[m
[32m+[m	[32mexception_entry error_el0_32[m
 [m
 sync_el1t:[m
 	handle_entry	1, SYNC_EL1t[m
[36m@@ -153,9 +183,12 @@[m [msync_el0_64:[m
 	mrs	x1, esr_el1[m
 	mrs	x2, elr_el1[m
 	bl	handle_entry_c[m
[31m-	exception_exit[m
[32m+[m	[32mexception_return[m
 [m
 el0_syscall:[m
[32m+[m	[32m/* 	Lab4[m[41m [m
[32m+[m	[32m* 	Acquire the big kernel lock for syscall[m
[32m+[m	[32m*/[m
 	sub	sp, sp, #16 * 8[m
 	stp	x0, x1, [sp, #16 * 0][m
 	stp	x2, x3, [sp, #16 * 1][m
[36m@@ -165,6 +198,9 @@[m [mel0_syscall:[m
 	stp	x10, x11, [sp, #16 * 5][m
 	stp	x12, x13, [sp, #16 * 6][m
 	stp	x14, x15, [sp, #16 * 7][m
[32m+[m
[32m+[m	[32mbl lock_kernel[m
[32m+[m
 	ldp	x0, x1, [sp, #16 * 0][m
 	ldp	x2, x3, [sp, #16 * 1][m
 	ldp	x4, x5, [sp, #16 * 2][m
[36m@@ -183,13 +219,21 @@[m [mel0_syscall:[m
 	/* Ret from syscall */[m
 	// bl	disable_irq[m
 	str	x0, [sp] /* set the return value of the syscall */[m
[31m-	exception_exit[m
[32m+[m	[32mexception_return[m
 	[m
 irq_el1h:[m
[31m-	handle_entry	0, IRQ_EL1h[m
[32m+[m	[32mexception_enter[m
[32m+[m	[32mmov	x0, IRQ_EL1h[m
[32m+[m	[32mbl	handle_irq[m
[32m+[m	[32m/* should nerver reach here */[m
[32m+[m	[32mb .[m
 [m
 irq_el0_64:[m
[31m-	handle_entry	0,  IRQ_EL0_64[m
[32m+[m	[32mexception_enter[m
[32m+[m	[32mmov	x0, IRQ_EL0_64[m
[32m+[m	[32mbl	handle_irq[m
[32m+[m	[32m/* should nerver reach here */[m
[32m+[m	[32mb .[m
 [m
 fiq_el0_64:[m
 	handle_entry	0, FIQ_EL0_64[m
[36m@@ -212,5 +256,5 @@[m [merror_el0_32:[m
 /* void eret_to_thread(u64 sp) */[m
 BEGIN_FUNC(eret_to_thread)[m
 	mov	sp, x0[m
[31m-	exception_exit[m
[32m+[m	[32mexception_return[m
 END_FUNC(eret_to_thread)[m
[1mdiff --git a/kernel/exception/irq.c b/kernel/exception/irq.c[m
[1mnew file mode 100644[m
[1mindex 0000000..63a3a07[m
[1m--- /dev/null[m
[1m+++ b/kernel/exception/irq.c[m
[36m@@ -0,0 +1,69 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <exception/irq.h>[m
[32m+[m[32m#include <exception/timer.h>[m
[32m+[m[32m#include <exception/exception.h>[m
[32m+[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/uart.h>[m
[32m+[m[32m#include <common/machine.h>[m
[32m+[m[32m#include <common/lock.h>[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/bitops.h>[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/tools.h>[m
[32m+[m
[32m+[m[32m/* Per core IRQ SOURCE MMIO address */[m
[32m+[m[32mu64 core_irq_source[PLAT_CPU_NUM] = {[m
[32m+[m	[32mCORE0_IRQ,[m
[32m+[m	[32mCORE1_IRQ,[m
[32m+[m	[32mCORE2_IRQ,[m
[32m+[m	[32mCORE3_IRQ[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mvoid handle_irq(int type)[m
[32m+[m[32m{[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Acquire the big kernel lock, if :[m
[32m+[m	[32m *	The irq is from the kernel[m
[32m+[m	[32m * 	The thread being interrupted is an idle thread.[m
[32m+[m	[32m */[m
[32m+[m
[32m+[m	[32mplat_handle_irq();[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Do you miss something?[m
[32m+[m	[32m */[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid plat_handle_irq(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 cpuid = 0;[m
[32m+[m	[32munsigned int irq_src, irq;[m
[32m+[m
[32m+[m	[32mcpuid = smp_get_cpu_id();[m
[32m+[m	[32mirq_src = get32(core_irq_source[cpuid]);[m
[32m+[m
[32m+[m	[32mirq = 1 << ctzl(irq_src);[m
[32m+[m	[32mswitch (irq) {[m
[32m+[m	[32mcase INT_SRC_TIMER3:[m
[32m+[m		[32mhandle_timer_irq();[m
[32m+[m		[32mbreak;[m
[32m+[m	[32mdefault:[m
[32m+[m		[32mkinfo("Unsupported IRQ %d\n", irq);[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/exception/irq.h b/kernel/exception/irq.h[m
[1mindex 01f75ab..9c5b243 100644[m
[1m--- a/kernel/exception/irq.h[m
[1m+++ b/kernel/exception/irq.h[m
[36m@@ -18,6 +18,11 @@[m
 #define MAX_IRQ_NUM	256[m
 #define HANDLE_KERNEL	0[m
 #define HANDLE_USER	1[m
[32m+[m[32mextern u8 irq_handle_type[MAX_IRQ_NUM];[m
 [m
 void enable_irq(void);[m
 void disable_irq(void);[m
[32m+[m
[32m+[m[32mvoid plat_handle_irq(void);[m
[32m+[m[32mvoid plat_disable_timer(void);[m
[32m+[m[32mvoid plat_enable_timer(void);[m
[1mdiff --git a/kernel/exception/pgfault.c b/kernel/exception/pgfault.c[m
[1mindex 33588d7..df08684 100644[m
[1m--- a/kernel/exception/pgfault.c[m
[1m+++ b/kernel/exception/pgfault.c[m
[36m@@ -86,6 +86,20 @@[m [mint handle_trans_fault(struct vmspace *vmspace, vaddr_t fault_addr)[m
 	 * are recorded in a radix tree for easy management. Such code[m
 	 * has been omitted in our lab for simplification.[m
 	 */[m
[32m+[m	[32mvmr = find_vmr_for_va(vmspace, fault_addr);[m
[32m+[m	[32mif(vmr == NULL){[m
[32m+[m		[32mreturn -ENOMAPPING;[m
[32m+[m	[32m}[m
[32m+[m	[32mpmo = vmr->pmo;[m
[32m+[m	[32mif(pmo->type != PMO_ANONYM){[m
[32m+[m		[32mreturn -ENOMAPPING;[m
[32m+[m	[32m}[m
 [m
[32m+[m	[32mpa = (paddr_t) virt_to_phys(kmalloc(pmo->size));[m
[32m+[m	[32mpmo->start = pa;[m
[32m+[m
[32m+[m	[32mif(map_range_in_pgtbl(vmspace->pgtbl, vmr->start, pa, pmo->size, vmr->perm) < 0){[m
[32m+[m		[32mreturn -ENOMAPPING;[m
[32m+[m	[32m}[m
 	return 0;[m
 }[m
[1mdiff --git a/kernel/exception/timer.c b/kernel/exception/timer.c[m
[1mnew file mode 100644[m
[1mindex 0000000..acca8d4[m
[1m--- /dev/null[m
[1m+++ b/kernel/exception/timer.c[m
[36m@@ -0,0 +1,90 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/machine.h>[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/tools.h>[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m[32m#include <exception/irq.h>[m
[32m+[m[32m#include <exception/timer.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m
[32m+[m[32mu64 cntv_tval;[m
[32m+[m
[32m+[m[32m/* Per core IRQ SOURCE MMIO address */[m
[32m+[m[32mu64 core_timer_irqcntl[PLAT_CPU_NUM] = {[m
[32m+[m	[32mCORE0_TIMER_IRQCNTL, CORE1_TIMER_IRQCNTL, CORE2_TIMER_IRQCNTL,[m
[32m+[m	[32mCORE3_TIMER_IRQCNTL[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mvoid timer_init(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 cur_freq = 0;[m
[32m+[m	[32mu64 cur_cnt = 0;[m
[32m+[m	[32mu64 count_down = 0;[m
[32m+[m	[32mu64 timer_ctl = 0;[m
[32m+[m	[32mu32 cpuid = smp_get_cpu_id();[m
[32m+[m
[32m+[m	[32m/* Since QEMU only emulate the generic timer, we use the generic timer[m
[32m+[m	[32m * here */[m
[32m+[m	[32masm volatile ("mrs %0, cntpct_el0":"=r" (cur_cnt));[m
[32m+[m	[32mkdebug("timer init cntpct_el0 = %lu\n", cur_cnt);[m
[32m+[m	[32masm volatile ("mrs %0, cntfrq_el0":"=r" (cur_freq));[m
[32m+[m	[32mkdebug("timer init cntfrq_el0 = %lu\n", cur_freq);[m
[32m+[m
[32m+[m	[32m/* Calculate the tv */[m
[32m+[m	[32mcntv_tval = (cur_freq * TICK_MS / 1000);[m
[32m+[m	[32mkdebug("CPU freq %lu, set timer %lu\n", cur_freq, cntv_tval);[m
[32m+[m
[32m+[m	[32m/* set the timervalue here */[m
[32m+[m	[32masm volatile ("msr cntv_tval_el0, %0"::"r" (cntv_tval));[m
[32m+[m	[32masm volatile ("mrs %0, cntv_tval_el0":"=r" (count_down));[m
[32m+[m	[32mkdebug("timer init cntv_tval_el0 = %lu\n", count_down);[m
[32m+[m
[32m+[m	[32mput32(core_timer_irqcntl[cpuid], INT_SRC_TIMER3);[m
[32m+[m
[32m+[m	[32m/* Set the control register */[m
[32m+[m	[32mtimer_ctl = 0 << 1 | 1;	/* IMASK = 0 ENABLE = 1 */[m
[32m+[m	[32masm volatile ("msr cntv_ctl_el0, %0"::"r" (timer_ctl));[m
[32m+[m	[32masm volatile ("mrs %0, cntv_ctl_el0":"=r" (timer_ctl));[m
[32m+[m	[32mkdebug("timer init cntv_ctl_el0 = %lu\n", timer_ctl);[m
[32m+[m	[32m/* enable interrupt controller */[m
[32m+[m	[32mreturn;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid plat_handle_timer_irq(void)[m
[32m+[m[32m{[m
[32m+[m	[32masm volatile ("msr cntv_tval_el0, %0"::"r" (cntv_tval));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid plat_disable_timer(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 timer_ctl = 0x0;[m
[32m+[m
[32m+[m	[32masm volatile ("msr cntv_ctl_el0, %0"::"r" (timer_ctl));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid plat_enable_timer(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 timer_ctl = 0x1;[m
[32m+[m
[32m+[m	[32masm volatile ("msr cntv_tval_el0, %0"::"r" (cntv_tval));[m
[32m+[m	[32masm volatile ("msr cntv_ctl_el0, %0"::"r" (timer_ctl));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid handle_timer_irq(void)[m
[32m+[m[32m{[m
[32m+[m	[32mplat_handle_timer_irq();[m
[32m+[m	[32msched_handle_timer_irq();[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/exception/timer.h b/kernel/exception/timer.h[m
[1mnew file mode 100644[m
[1mindex 0000000..564d1ea[m
[1m--- /dev/null[m
[1m+++ b/kernel/exception/timer.h[m
[36m@@ -0,0 +1,17 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32mvoid timer_init(void);[m
[32m+[m[32mvoid handle_timer_irq(void);[m
[32m+[m[32mvoid plat_handle_timer_irq(void);[m
[1mdiff --git a/kernel/head.S b/kernel/head.S[m
[1mindex 133d786..25143da 100644[m
[1m--- a/kernel/head.S[m
[1m+++ b/kernel/head.S[m
[36m@@ -28,3 +28,16 @@[m [mBEGIN_FUNC(start_kernel)[m
     mov     sp, x2[m
     bl      main[m
 END_FUNC(start_kernel)[m
[32m+[m
[32m+[m[32mBEGIN_FUNC(secondary_cpu_boot)[m
[32m+[m[32m    /* We store the logical cpuid in TPIDR_EL1 */[m
[32m+[m[32m    msr     TPIDR_EL1, x0[m
[32m+[m
[32m+[m[32m    mov     x1, #KERNEL_STACK_SIZE[m
[32m+[m[32m    mul     x2, x0, x1[m
[32m+[m[32m    ldr     x3, =kernel_stack[m
[32m+[m[32m    add     x2, x2, x3[m
[32m+[m[32m    add     x2, x2, KERNEL_STACK_SIZE[m
[32m+[m[32m    mov     sp, x2[m
[32m+[m[32m    bl      secondary_start[m
[32m+[m[32mEND_FUNC(secondary_cpu_boot)[m
\ No newline at end of file[m
[1mdiff --git a/kernel/ipc/CMakeLists.txt b/kernel/ipc/CMakeLists.txt[m
[1mnew file mode 100644[m
[1mindex 0000000..3ba4f4e[m
[1m--- /dev/null[m
[1m+++ b/kernel/ipc/CMakeLists.txt[m
[36m@@ -0,0 +1,9 @@[m
[32m+[m[32mcmake_minimum_required(VERSION 3.14)[m
[32m+[m
[32m+[m
[32m+[m[32mfile(GLOB OBJECT_SOURCE "*.c")[m
[32m+[m[32madd_library(${PROJECT_NAME}-ipc OBJECT ${OBJECT_SOURCE})[m
[32m+[m[32mtarget_include_directories([m
[32m+[m	[32m${PROJECT_NAME}-ipc[m
[32m+[m	[32mPUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include"[m
[32m+[m[32m)[m
\ No newline at end of file[m
[1mdiff --git a/kernel/ipc/ipc.h b/kernel/ipc/ipc.h[m
[1mnew file mode 100644[m
[1mindex 0000000..7ec5c92[m
[1m--- /dev/null[m
[1m+++ b/kernel/ipc/ipc.h[m
[36m@@ -0,0 +1,79 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m/* This file defines ds and interfaces related with synchronous IPC (Thread[m
[32m+[m[32m * migatation) */[m
[32m+[m[32m#pragma once[m
[32m+[m[32m#include <common/list.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Used in both server and client register.[m
[32m+[m[32m * Stack setting is invalid in client register.[m
[32m+[m[32m */[m
[32m+[m[32mstruct ipc_vm_config {[m
[32m+[m	[32mu64 stack_base_addr;[m
[32m+[m	[32mu64 stack_size;[m
[32m+[m	[32mu64 buf_base_addr;[m
[32m+[m	[32mu64 buf_size;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m#define IPC_MAX_CONN_PER_SERVER 32[m
[32m+[m[32mstruct server_ipc_config {[m
[32m+[m	[32m// I dont know how to specify the maximum callback number[m
[32m+[m	[32mu64 callback;[m
[32m+[m	[32mu64 max_client;[m
[32m+[m	[32m/* bitmap for shared buffer and stack allocation */[m
[32m+[m	[32munsigned long *conn_bmp;[m
[32m+[m	[32mstruct ipc_vm_config vm_config;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct shared_buf {[m
[32m+[m	[32mu64 client_user_addr;[m
[32m+[m	[32mu64 server_user_addr;[m
[32m+[m	[32mu64 size;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct ipc_connection {[m
[32m+[m	[32m/* Source Thread */[m
[32m+[m	[32mstruct thread *source;[m
[32m+[m	[32m/* Target Thread */[m
[32m+[m	[32mstruct thread *target;[m
[32m+[m	[32m/* Conn cap in server */[m
[32m+[m	[32mu64 server_conn_cap;[m
[32m+[m	[32m/* Target function */[m
[32m+[m	[32mu64 callback;[m
[32m+[m
[32m+[m	[32m/* Shadow server stack top */[m
[32m+[m	[32mu64 server_stack_top;[m
[32m+[m	[32mu64 server_stack_size;[m
[32m+[m
[32m+[m	[32m/* Shared buffer */[m
[32m+[m	[32mstruct shared_buf buf;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mtypedef struct ipc_msg {[m
[32m+[m	[32mu64 server_conn_cap;[m
[32m+[m	[32mu64 data_len;[m
[32m+[m	[32mu64 cap_slot_number;[m
[32m+[m	[32mu64 data_offset;[m
[32m+[m	[32mu64 cap_slots_offset;[m
[32m+[m[32m} ipc_msg_t;[m
[32m+[m
[32m+[m[32m/* syscall related to IPC */[m
[32m+[m[32mu64 sys_register_server(u64 callback, u64 max_client, u64 vm_config_ptr);[m
[32m+[m[32mu32 sys_register_client(u32 server_cap, u64 vm_config_ptr);[m
[32m+[m[32mu64 sys_ipc_call(u32 conn_cap, ipc_msg_t * ipc_msg);[m
[32m+[m[32mu64 sys_ipc_reg_call(u32 conn_cap, u64 arg);[m
[32m+[m[32mvoid sys_ipc_return(u64 ret);[m
[32m+[m
[32m+[m[32m#define LAB4_IPC_BLANK 0[m
[1mdiff --git a/kernel/ipc/ipc_call.c b/kernel/ipc/ipc_call.c[m
[1mnew file mode 100644[m
[1mindex 0000000..9c130a0[m
[1m--- /dev/null[m
[1m+++ b/kernel/ipc/ipc_call.c[m
[36m@@ -0,0 +1,200 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/util.h>[m
[32m+[m[32m#include <ipc/ipc.h>[m
[32m+[m[32m#include <exception/exception.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <common/mm.h>[m
[32m+[m[32m#include <common/uaccess.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <sched/context.h>[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * A helper function to transfer all the ipc_msg's capbilities of client's[m
[32m+[m[32m * process to server's process[m
[32m+[m[32m */[m
[32m+[m[32m#define MAX_CAP_TRANSFER 8[m
[32m+[m[32mint ipc_send_cap(struct ipc_connection *conn, ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mint i, r;[m
[32m+[m	[32mu64 cap_slot_number;[m
[32m+[m	[32mu64 cap_slots_offset;[m
[32m+[m	[32mu64 *cap_buf;[m
[32m+[m
[32m+[m	[32mr = copy_from_user((char *)&cap_slot_number,[m
[32m+[m			[32m   (char *)&ipc_msg->cap_slot_number,[m
[32m+[m			[32m   sizeof(cap_slot_number));[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out;[m
[32m+[m	[32mif (likely(cap_slot_number == 0)) {[m
[32m+[m		[32mr = 0;[m
[32m+[m		[32mgoto out;[m
[32m+[m	[32m} else if (cap_slot_number >= MAX_CAP_TRANSFER) {[m
[32m+[m		[32mr = -EINVAL;[m
[32m+[m		[32mgoto out;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mr = copy_from_user((char *)&cap_slots_offset,[m
[32m+[m			[32m   (char *)&ipc_msg->cap_slots_offset,[m
[32m+[m			[32m   sizeof(cap_slots_offset));[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out;[m
[32m+[m
[32m+[m	[32mcap_buf = kmalloc(cap_slot_number * sizeof(*cap_buf));[m
[32m+[m	[32mif (!cap_buf) {[m
[32m+[m		[32mr = -ENOMEM;[m
[32m+[m		[32mgoto out;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mr = copy_from_user((char *)cap_buf, (char *)ipc_msg + cap_slots_offset,[m
[32m+[m			[32m   sizeof(*cap_buf) * cap_slot_number);[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out;[m
[32m+[m
[32m+[m	[32mfor (i = 0; i < cap_slot_number; i++) {[m
[32m+[m		[32mu64 dest_cap;[m
[32m+[m
[32m+[m		[32mkdebug("[IPC] send cap:%d\n", cap_buf[i]);[m
[32m+[m		[32mdest_cap = cap_copy(current_process, conn->target->process,[m
[32m+[m				[32m    cap_buf[i], false, 0);[m
[32m+[m		[32mif (dest_cap < 0)[m
[32m+[m			[32mgoto out_free_cap;[m
[32m+[m		[32mcap_buf[i] = dest_cap;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mr = copy_to_user((char *)ipc_msg + cap_slots_offset, (char *)cap_buf,[m
[32m+[m			[32m sizeof(*cap_buf) * cap_slot_number);[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out_free_cap;[m
[32m+[m
[32m+[m	[32mkfree(cap_buf);[m
[32m+[m	[32mreturn 0;[m
[32m+[m
[32m+[m[32m out_free_cap:[m
[32m+[m	[32mfor (--i; i >= 0; i--)[m
[32m+[m		[32mcap_free(conn->target->process, cap_buf[i]);[m
[32m+[m	[32mkfree(cap_buf);[m
[32m+[m[32m out:[m
[32m+[m	[32mreturn r;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Helper function[m
[32m+[m[32m * Client thread calls this function and then return to server thread[m
[32m+[m[32m * This function should never return[m
[32m+[m[32m *[m
[32m+[m[32m * Replace the place_holder to correct value![m
[32m+[m[32m */[m
[32m+[m[32mstatic u64 thread_migrate_to_server(struct ipc_connection *conn, u64 arg)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *target = conn->target;[m
[32m+[m
[32m+[m	[32mconn->source = current_thread;[m
[32m+[m	[32mtarget->active_conn = conn;[m
[32m+[m	[32mcurrent_thread->thread_ctx->state = TS_WAITING;[m
[32m+[m	[32mobj_put(conn);[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * This command set the sp register, read the file to find which field[m
[32m+[m	[32m * of the ipc_connection stores the stack of the server thread?[m
[32m+[m	[32m * */[m
[32m+[m	[32march_set_thread_stack(target, LAB4_IPC_BLANK);[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * This command set the ip register, read the file to find which field[m
[32m+[m	[32m * of the ipc_connection stores the instruction to be called when switch[m
[32m+[m	[32m * to the server?[m
[32m+[m	[32m * */[m
[32m+[m	[32march_set_thread_next_ip(target, LAB4_IPC_BLANK);[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * The argument set by sys_ipc_call;[m
[32m+[m	[32m */[m
[32m+[m	[32march_set_thread_arg(target, LAB4_IPC_BLANK);[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Passing the scheduling context of the current thread to thread of[m
[32m+[m	[32m * connection[m
[32m+[m	[32m */[m
[32m+[m	[32mtarget->thread_ctx->sc = current_thread->thread_ctx->sc;[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Switch to the server[m
[32m+[m	[32m */[m
[32m+[m	[32mswitch_to_thread(target);[m
[32m+[m	[32meret_to_thread(switch_context());[m
[32m+[m
[32m+[m	[32m/* Function never return */[m
[32m+[m	[32mBUG_ON(1);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * The client thread calls sys_ipc_call to migrate to the server thread.[m
[32m+[m[32m * When you transfer the ipc_msg (which is the virtual address in the client[m
[32m+[m[32m * vmspace), do not forget to change the virtual address to server's vmspace.[m
[32m+[m[32m * This function should never return![m
[32m+[m[32m */[m
[32m+[m[32mu64 sys_ipc_call(u32 conn_cap, ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct ipc_connection *conn = NULL;[m
[32m+[m	[32mu64 arg;[m
[32m+[m	[32mint r;[m
[32m+[m
[32m+[m	[32mconn = obj_get(current_thread->process, conn_cap, TYPE_CONNECTION);[m
[32m+[m	[32mif (!conn) {[m
[32m+[m		[32mr = -ECAPBILITY;[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Here, you need to transfer all the capbiliies of client thread to[m
[32m+[m	[32m * capbilities in server thread in the ipc_msg.[m
[32m+[m	[32m */[m
[32m+[m
[32m+[m	[32mr = copy_to_user((char *)&ipc_msg->server_conn_cap,[m
[32m+[m			[32m (char *)&conn->server_conn_cap, sizeof(u64));[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out_obj_put;[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * The arg is actually the 64-bit arg for ipc_dispatcher[m
[32m+[m	[32m * Then what value should the arg be?[m
[32m+[m	[32m * */[m
[32m+[m	[32marg = LAB4_IPC_BLANK;[m
[32m+[m	[32mthread_migrate_to_server(conn, arg);[m
[32m+[m
[32m+[m	[32mBUG("This function should never\n");[m
[32m+[m[32m out_obj_put:[m
[32m+[m	[32mobj_put(conn);[m
[32m+[m[32m out_fail:[m
[32m+[m	[32mreturn r;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Implement your sys_ipc_reg_call[m
[32m+[m[32m * */[m
[32m+[m[32mu64 sys_ipc_reg_call(u32 conn_cap, u64 arg0)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn -1;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/ipc/ipc_client.c b/kernel/ipc/ipc_client.c[m
[1mnew file mode 100644[m
[1mindex 0000000..241bb45[m
[1m--- /dev/null[m
[1m+++ b/kernel/ipc/ipc_client.c[m
[36m@@ -0,0 +1,223 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/util.h>[m
[32m+[m[32m#include <ipc/ipc.h>[m
[32m+[m[32m#include <exception/irq.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <common/mm.h>[m
[32m+[m[32m#include <common/uaccess.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <sched/context.h>[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m
[32m+[m[32m#define SHADOW_THREAD_PRIO MAX_PRIO - 1[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Helper function called when an ipc_connection is created[m
[32m+[m[32m */[m
[32m+[m[32mstatic struct thread *create_server_thread(struct thread *src)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *new;[m
[32m+[m
[32m+[m	[32mnew = kmalloc(sizeof(struct thread));[m
[32m+[m	[32mBUG_ON(new == NULL);[m
[32m+[m
[32m+[m	[32mnew->vmspace = obj_get(src->process, VMSPACE_OBJ_ID, TYPE_VMSPACE);[m
[32m+[m	[32mBUG_ON(!new->vmspace);[m
[32m+[m
[32m+[m	[32m// Init the thread ctx[m
[32m+[m	[32mnew->thread_ctx = create_thread_ctx();[m
[32m+[m	[32mif (!new->thread_ctx)[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32mmemcpy((char *)&(new->thread_ctx->ec),[m
[32m+[m	[32m       (const char *)&(src->thread_ctx->ec), sizeof(arch_exec_cont_t));[m
[32m+[m	[32mnew->thread_ctx->prio = SHADOW_THREAD_PRIO;[m
[32m+[m	[32mnew->thread_ctx->state = TS_INIT;[m
[32m+[m	[32mnew->thread_ctx->affinity = NO_AFF;[m
[32m+[m	[32mnew->thread_ctx->sc = NULL;[m
[32m+[m	[32mnew->thread_ctx->type = TYPE_SHADOW;[m
[32m+[m
[32m+[m	[32m// Init the server ipc[m
[32m+[m	[32mnew->server_ipc_config = kzalloc(sizeof(struct server_ipc_config));[m
[32m+[m	[32mif (!new->server_ipc_config)[m
[32m+[m		[32mgoto out_destroy_thread_ctx;[m
[32m+[m	[32mnew->server_ipc_config->callback = src->server_ipc_config->callback;[m
[32m+[m	[32mnew->server_ipc_config->vm_config = src->server_ipc_config->vm_config;[m
[32m+[m	[32mnew->process = src->process;[m
[32m+[m
[32m+[m	[32mobj_put(new->vmspace);[m
[32m+[m	[32mreturn new;[m
[32m+[m
[32m+[m[32m out_destroy_thread_ctx:[m
[32m+[m	[32mdestroy_thread_ctx(new);[m
[32m+[m[32m out_fail:[m
[32m+[m	[32mobj_put(new->vmspace);[m
[32m+[m	[32mkfree(new);[m
[32m+[m	[32mreturn NULL;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Helper function to create an ipc_connection by the client thread[m
[32m+[m[32m */[m
[32m+[m[32mstatic int create_connection(struct thread *source, struct thread *target,[m
[32m+[m			[32m     struct ipc_vm_config *client_vm_config)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct ipc_connection *conn = NULL;[m
[32m+[m	[32mint ret = 0;[m
[32m+[m	[32mint conn_cap = 0, server_conn_cap = 0;[m
[32m+[m	[32mstruct pmobject *stack_pmo, *buf_pmo;[m
[32m+[m	[32mint conn_idx;[m
[32m+[m	[32mstruct server_ipc_config *server_ipc_config;[m
[32m+[m	[32mstruct ipc_vm_config *vm_config;[m
[32m+[m	[32mu64 server_stack_base, server_buf_base, client_buf_base;[m
[32m+[m	[32mu64 stack_size, buf_size;[m
[32m+[m
[32m+[m	[32mBUG_ON(source == NULL);[m
[32m+[m	[32mBUG_ON(target == NULL);[m
[32m+[m
[32m+[m	[32m// Get the ipc_connection[m
[32m+[m	[32mconn = obj_alloc(TYPE_CONNECTION, sizeof(*conn));[m
[32m+[m	[32mif (!conn) {[m
[32m+[m		[32mret = -ENOMEM;[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32m}[m
[32m+[m	[32mconn->target = create_server_thread(target);[m
[32m+[m	[32mif (!conn->target) {[m
[32m+[m		[32mret = -ENOMEM;[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32m}[m
[32m+[m	[32m// Get the server's ipc config[m
[32m+[m	[32mserver_ipc_config = target->server_ipc_config;[m
[32m+[m	[32mvm_config = &server_ipc_config->vm_config;[m
[32m+[m	[32mconn_idx = find_next_zero_bit(server_ipc_config->conn_bmp,[m
[32m+[m				[32m      server_ipc_config->max_client, 0);[m
[32m+[m	[32mset_bit(conn_idx, server_ipc_config->conn_bmp);[m
[32m+[m
[32m+[m	[32m// Create the server thread's stack[m
[32m+[m	[32mserver_stack_base =[m
[32m+[m	[32m    vm_config->stack_base_addr + conn_idx * vm_config->stack_size;[m
[32m+[m	[32mstack_size = vm_config->stack_size;[m
[32m+[m	[32mkdebug("server stack base:%lx size:%lx\n", server_stack_base,[m
[32m+[m	[32m       stack_size);[m
[32m+[m	[32mstack_pmo = kmalloc(sizeof(struct pmobject));[m
[32m+[m	[32mif (!stack_pmo) {[m
[32m+[m		[32mret = -ENOMEM;[m
[32m+[m		[32mgoto out_free_obj;[m
[32m+[m	[32m}[m
[32m+[m	[32mpmo_init(stack_pmo, PMO_DATA, stack_size, 0);[m
[32m+[m	[32mvmspace_map_range(target->vmspace, server_stack_base, stack_size,[m
[32m+[m			[32m  VMR_READ | VMR_WRITE, stack_pmo);[m
[32m+[m
[32m+[m	[32mconn->server_stack_top = server_stack_base + stack_size;[m
[32m+[m
[32m+[m	[32m// Create and map the shared buffer for client and server[m
[32m+[m	[32mserver_buf_base =[m
[32m+[m	[32m    vm_config->buf_base_addr + conn_idx * vm_config->buf_size;[m
[32m+[m	[32mclient_buf_base = client_vm_config->buf_base_addr;[m
[32m+[m	[32mbuf_size = MIN(vm_config->buf_size, client_vm_config->buf_size);[m
[32m+[m	[32mclient_vm_config->buf_size = buf_size;[m
[32m+[m	[32mkdebug("server buf base:%lx size:%lx, client base:%lx\n",[m
[32m+[m	[32m       server_stack_base, stack_size, client_buf_base);[m
[32m+[m
[32m+[m	[32mbuf_pmo = kmalloc(sizeof(struct pmobject));[m
[32m+[m	[32mif (!buf_pmo) {[m
[32m+[m		[32mret = -ENOMEM;[m
[32m+[m		[32mgoto out_free_stack_pmo;[m
[32m+[m	[32m}[m
[32m+[m	[32mpmo_init(buf_pmo, PMO_DATA, buf_size, 0);[m
[32m+[m
[32m+[m	[32mvmspace_map_range(current_thread->vmspace, client_buf_base, buf_size,[m
[32m+[m			[32m  VMR_READ | VMR_WRITE, buf_pmo);[m
[32m+[m	[32mvmspace_map_range(target->vmspace, server_buf_base, buf_size,[m
[32m+[m			[32m  VMR_READ | VMR_WRITE, buf_pmo);[m
[32m+[m
[32m+[m	[32mconn->buf.client_user_addr = client_buf_base;[m
[32m+[m	[32mconn->buf.server_user_addr = server_buf_base;[m
[32m+[m
[32m+[m	[32mconn_cap = cap_alloc(current_process, conn, 0);[m
[32m+[m	[32mif (conn_cap < 0) {[m
[32m+[m		[32mret = conn_cap;[m
[32m+[m		[32mgoto out_free_obj;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mserver_conn_cap =[m
[32m+[m	[32m    cap_copy(current_process, target->process, conn_cap, 0, 0);[m
[32m+[m	[32mif (server_conn_cap < 0) {[m
[32m+[m		[32mret = server_conn_cap;[m
[32m+[m		[32mgoto out_free_obj;[m
[32m+[m	[32m}[m
[32m+[m	[32mconn->server_conn_cap = server_conn_cap;[m
[32m+[m
[32m+[m	[32mreturn conn_cap;[m
[32m+[m[32m out_free_stack_pmo:[m
[32m+[m	[32mkfree(stack_pmo);[m
[32m+[m[32m out_free_obj:[m
[32m+[m	[32mobj_free(conn);[m
[32m+[m[32m out_fail:[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mu32 sys_register_client(u32 server_cap, u64 vm_config_ptr)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *client = current_thread;[m
[32m+[m	[32mstruct thread *server = NULL;[m
[32m+[m	[32mstruct ipc_connection *conn;[m
[32m+[m	[32mstruct ipc_vm_config vm_config = { 0 };[m
[32m+[m	[32mu64 client_buf_size;[m
[32m+[m	[32mint conn_cap = 0;[m
[32m+[m	[32mint r = 0;[m
[32m+[m
[32m+[m	[32mr = copy_from_user((char *)&vm_config, (char *)vm_config_ptr,[m
[32m+[m			[32m   sizeof(vm_config));[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32mif (!is_user_addr_range(vm_config.buf_base_addr, vm_config.buf_size) ||[m
[32m+[m	[32m    !IS_ALIGNED(vm_config.buf_base_addr, PAGE_SIZE) ||[m
[32m+[m	[32m    !IS_ALIGNED(vm_config.buf_size, PAGE_SIZE)) {[m
[32m+[m		[32mr = -EINVAL;[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mserver = obj_get(current_thread->process, server_cap, TYPE_THREAD);[m
[32m+[m	[32mif (!server) {[m
[32m+[m		[32mr = -ECAPBILITY;[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mclient_buf_size = vm_config.buf_size;[m
[32m+[m	[32mconn_cap = create_connection(client, server, &vm_config);[m
[32m+[m	[32mif (conn_cap < 0) {[m
[32m+[m		[32mr = conn_cap;[m
[32m+[m		[32mgoto out_obj_put_thread;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mconn = obj_get(current_process, conn_cap, TYPE_CONNECTION);[m
[32m+[m
[32m+[m	[32mif (client_buf_size != vm_config.buf_size) {[m
[32m+[m		[32mr = copy_to_user((char *)vm_config_ptr, (char *)&vm_config,[m
[32m+[m				[32m sizeof(vm_config));[m
[32m+[m		[32mif (r < 0)[m
[32m+[m			[32mgoto out_obj_put_conn;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mr = conn_cap;[m
[32m+[m[32m out_obj_put_conn:[m
[32m+[m	[32mobj_put(conn);[m
[32m+[m[32m out_obj_put_thread:[m
[32m+[m	[32mobj_put(server);[m
[32m+[m[32m out_fail:[m
[32m+[m	[32mreturn r;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/ipc/ipc_return.c b/kernel/ipc/ipc_return.c[m
[1mnew file mode 100644[m
[1mindex 0000000..97fbb97[m
[1m--- /dev/null[m
[1m+++ b/kernel/ipc/ipc_return.c[m
[36m@@ -0,0 +1,74 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/util.h>[m
[32m+[m[32m#include <ipc/ipc.h>[m
[32m+[m[32m#include <exception/exception.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <common/mm.h>[m
[32m+[m[32m#include <common/uaccess.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <sched/context.h>[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Helper function[m
[32m+[m[32m * Server thread calls this function and then return to client thread[m
[32m+[m[32m * This function should never return[m
[32m+[m[32m *[m
[32m+[m[32m * Replace the place_holder to correct value![m
[32m+[m[32m */[m
[32m+[m[32mstatic int thread_migrate_to_client(struct ipc_connection *conn, u64 ret_value)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *source = conn->source;[m
[32m+[m	[32mcurrent_thread->active_conn = NULL;[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * The return value returned by server thread;[m
[32m+[m	[32m */[m
[32m+[m	[32march_set_thread_return(source, LAB4_IPC_BLANK);[m
[32m+[m	[32m/**[m
[32m+[m	[32m * Switch to the client[m
[32m+[m	[32m */[m
[32m+[m	[32mswitch_to_thread(source);[m
[32m+[m	[32meret_to_thread(switch_context());[m
[32m+[m
[32m+[m	[32m/* Function never return */[m
[32m+[m	[32mBUG_ON(1);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * The thread of ipc_connection calls sys_ipc_return[m
[32m+[m[32m * you should migrate to the client now.[m
[32m+[m[32m * This function should never return![m
[32m+[m[32m */[m
[32m+[m[32mvoid sys_ipc_return(u64 ret)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct ipc_connection *conn = current_thread->active_conn;[m
[32m+[m
[32m+[m	[32mif (conn == NULL) {[m
[32m+[m		[32mWARN("An inactive thread calls ipc_return\n");[m
[32m+[m		[32mgoto out;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mthread_migrate_to_client(conn, ret);[m
[32m+[m
[32m+[m	[32mBUG("This function should never\n");[m
[32m+[m[32m out:[m
[32m+[m	[32mreturn;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/ipc/ipc_server.c b/kernel/ipc/ipc_server.c[m
[1mnew file mode 100644[m
[1mindex 0000000..9549e86[m
[1m--- /dev/null[m
[1m+++ b/kernel/ipc/ipc_server.c[m
[36m@@ -0,0 +1,92 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/util.h>[m
[32m+[m[32m#include <ipc/ipc.h>[m
[32m+[m[32m#include <exception/irq.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <common/mm.h>[m
[32m+[m[32m#include <common/uaccess.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <sched/context.h>[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m
[32m+[m[32m#define SHADOW_THREAD_PRIO MAX_PRIO - 1[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * The core function for registering the server[m
[32m+[m[32m */[m
[32m+[m[32mstatic int register_server(struct thread *server, u64 callback, u64 max_client,[m
[32m+[m			[32m   u64 vm_config_ptr)[m
[32m+[m[32m{[m
[32m+[m	[32mint r;[m
[32m+[m	[32mstruct server_ipc_config *server_ipc_config;[m
[32m+[m	[32mstruct ipc_vm_config *vm_config;[m
[32m+[m	[32mBUG_ON(server == NULL);[m
[32m+[m
[32m+[m	[32m// Create the server ipc_config[m
[32m+[m	[32mserver_ipc_config = kmalloc(sizeof(struct server_ipc_config));[m
[32m+[m	[32mif (!server_ipc_config) {[m
[32m+[m		[32mr = -ENOMEM;[m
[32m+[m		[32mgoto out_fail;[m
[32m+[m	[32m}[m
[32m+[m	[32mserver->server_ipc_config = server_ipc_config;[m
[32m+[m
[32m+[m	[32m// Init the server ipc_config[m
[32m+[m	[32mserver_ipc_config->callback = callback;[m
[32m+[m	[32mif (max_client > IPC_MAX_CONN_PER_SERVER) {[m
[32m+[m		[32mr = -EINVAL;[m
[32m+[m		[32mgoto out_free_server_ipc_config;[m
[32m+[m	[32m}[m
[32m+[m	[32mserver_ipc_config->max_client = max_client;[m
[32m+[m	[32mserver_ipc_config->conn_bmp =[m
[32m+[m	[32m    kzalloc(BITS_TO_LONGS(max_client) * sizeof(long));[m
[32m+[m	[32mif (!server_ipc_config->conn_bmp) {[m
[32m+[m		[32mr = -ENOMEM;[m
[32m+[m		[32mgoto out_free_server_ipc_config;[m
[32m+[m	[32m}[m
[32m+[m	[32m// Get and check the parameter vm_config[m
[32m+[m	[32mvm_config = &server_ipc_config->vm_config;[m
[32m+[m	[32mr = copy_from_user((char *)vm_config, (char *)vm_config_ptr,[m
[32m+[m			[32m   sizeof(*vm_config));[m
[32m+[m	[32mif (r < 0)[m
[32m+[m		[32mgoto out_free_conn_bmp;[m
[32m+[m	[32mif (!is_user_addr_range(vm_config->stack_base_addr,[m
[32m+[m				[32mvm_config->stack_size) ||[m
[32m+[m	[32m    !is_user_addr_range(vm_config->buf_base_addr,[m
[32m+[m				[32mvm_config->buf_size) ||[m
[32m+[m	[32m    !IS_ALIGNED(vm_config->stack_base_addr, PAGE_SIZE) ||[m
[32m+[m	[32m    !IS_ALIGNED(vm_config->stack_size, PAGE_SIZE) ||[m
[32m+[m	[32m    !IS_ALIGNED(vm_config->buf_base_addr, PAGE_SIZE) ||[m
[32m+[m	[32m    !IS_ALIGNED(vm_config->buf_size, PAGE_SIZE)) {[m
[32m+[m		[32mr = -EINVAL;[m
[32m+[m		[32mgoto out_free_conn_bmp;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mreturn r;[m
[32m+[m
[32m+[m[32m out_free_conn_bmp:[m
[32m+[m	[32mkfree(server_ipc_config->conn_bmp);[m
[32m+[m[32m out_free_server_ipc_config:[m
[32m+[m	[32mkfree(server_ipc_config);[m
[32m+[m[32m out_fail:[m
[32m+[m	[32mreturn r;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mu64 sys_register_server(u64 callback, u64 max_client, u64 vm_config_ptr)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn register_server(current_thread, callback, max_client,[m
[32m+[m			[32m       vm_config_ptr);[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/main.c b/kernel/main.c[m
[1mindex 4366662..f66f11b 100644[m
[1m--- a/kernel/main.c[m
[1m+++ b/kernel/main.c[m
[36m@@ -11,15 +11,19 @@[m
  */[m
 [m
 #include <common/kprint.h>[m
[32m+[m[32m#include <common/lock.h>[m
 #include <common/machine.h>[m
 #include <common/macro.h>[m
 #include <common/mm.h>[m
[32m+[m[32m#include <common/smp.h>[m
 #include <common/uart.h>[m
 #include <common/vars.h>[m
 #include <exception/exception.h>[m
[32m+[m[32m#include <ipc/ipc.h>[m
 #include <common/types.h>[m
 #include <process/thread.h>[m
 #include <sched/sched.h>[m
[32m+[m[32m#include <tests/tests.h>[m
 [m
 ALIGN(STACK_ALIGNMENT)[m
 char kernel_stack[PLAT_CPU_NUM][KERNEL_STACK_SIZE];[m
[36m@@ -56,16 +60,70 @@[m [mvoid main(void *addr)[m
 	exception_init();[m
 	kinfo("[ChCore] interrupt init finished\n");[m
 [m
[32m+[m	[32m/**[m
[32m+[m	[32m *  Lab4[m
[32m+[m	[32m *  Initialize and then acquire the big kernel lock.[m
[32m+[m	[32m */[m
[32m+[m	[32mkernel_lock_init();[m
[32m+[m	[32mkinfo("[ChCore] lock init finished\n");[m
[32m+[m
[32m+[m	[32m/* Init scheduler with specified policy. */[m
[32m+[m	[32msched_init(&rr);[m
[32m+[m	[32mkinfo("[ChCore] sched init finished\n");[m
[32m+[m
[32m+[m[32m#ifndef TEST[m
[32m+[m	[32minit_test();[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m	[32m/* Other cores are busy looping on the addr, wake up those cores */[m
[32m+[m	[32menable_smp_cores(addr);[m
[32m+[m	[32mkinfo("[ChCore] boot multicore finished\n");[m
[32m+[m
 #ifdef TEST[m
 	/* Create initial thread here */[m
 	process_create_root(TEST);[m
 	kinfo("[ChCore] root thread init finished\n");[m
 #else[m
 	/* We will run the kernel test if you do not type make bin=xxx */[m
[32m+[m	[32mrun_test(true);[m
 	break_point();[m
 	BUG("No given TEST!");[m
 #endif[m
 [m
[32m+[m	[32m/**[m[41m [m
[32m+[m	[32m * Where the pimary CPU first returns to the user mode[m
[32m+[m	[32m * Leave the scheduler to do its job[m[41m [m
[32m+[m	[32m*/[m
[32m+[m	[32msched();[m
[32m+[m
[32m+[m	[32meret_to_thread(switch_context());[m
[32m+[m
[32m+[m	[32m/* Should provide panic and use here */[m
[32m+[m	[32mBUG("[FATAL] Should never be here!\n");[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid secondary_start(void)[m
[32m+[m[32m{[m
[32m+[m	[32mkinfo("AP %u is activated!\n", smp_get_cpu_id());[m
[32m+[m	[32mexception_init_per_cpu();[m
[32m+[m
[32m+[m	[32m/**[m[41m [m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Inform the BSP at last to start cpu one by one[m
[32m+[m	[32m * Hints: use cpu_status[m
[32m+[m	[32m*/[m
[32m+[m
[32m+[m[32m#ifndef TEST[m
[32m+[m	[32mrun_test(false);[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m	[32m/**[m
[32m+[m	[32m *  Lab4[m
[32m+[m	[32m *  Acquire the big kernel lock[m
[32m+[m	[32m */[m
[32m+[m
[32m+[m	[32m/* Where the AP first returns to the user mode */[m
[32m+[m	[32msched();[m
 	eret_to_thread(switch_context());[m
 [m
 	/* Should provide panic and use here */[m
[1mdiff --git a/kernel/mm/CMakeCache.txt b/kernel/mm/CMakeCache.txt[m
[1mnew file mode 100644[m
[1mindex 0000000..9a4a680[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeCache.txt[m
[36m@@ -0,0 +1,351 @@[m
[32m+[m[32m# This is the CMakeCache file.[m
[32m+[m[32m# For build in directory: /chos/kernel/mm[m
[32m+[m[32m# It was generated by CMake: /usr/local/bin/cmake[m
[32m+[m[32m# You can edit this file to change values found and used by cmake.[m
[32m+[m[32m# If you do not want to change any of the values, simply exit the editor.[m
[32m+[m[32m# If you do want to change a value, simply edit, save, and exit the editor.[m
[32m+[m[32m# The syntax for the file is as follows:[m
[32m+[m[32m# KEY:TYPE=VALUE[m
[32m+[m[32m# KEY is the name of a variable in the cache.[m
[32m+[m[32m# TYPE is a hint to GUIs for the type of VALUE, DO NOT EDIT TYPE!.[m
[32m+[m[32m# VALUE is the current value for the KEY.[m
[32m+[m
[32m+[m[32m########################[m
[32m+[m[32m# EXTERNAL cache entries[m
[32m+[m[32m########################[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_AR:FILEPATH=/usr/bin/ar[m
[32m+[m
[32m+[m[32m//Choose the type of build, options are: None Debug Release RelWithDebInfo[m
[32m+[m[32m// MinSizeRel ...[m
[32m+[m[32mCMAKE_BUILD_TYPE:STRING=[m
[32m+[m
[32m+[m[32m//Enable/Disable color output during build.[m
[32m+[m[32mCMAKE_COLOR_MAKEFILE:BOOL=ON[m
[32m+[m
[32m+[m[32m//CXX compiler[m
[32m+[m[32mCMAKE_CXX_COMPILER:FILEPATH=/usr/bin/c++[m
[32m+[m
[32m+[m[32m//A wrapper around 'ar' adding the appropriate '--plugin' option[m
[32m+[m[32m// for the GCC compiler[m
[32m+[m[32mCMAKE_CXX_COMPILER_AR:FILEPATH=/usr/bin/gcc-ar-7[m
[32m+[m
[32m+[m[32m//A wrapper around 'ranlib' adding the appropriate '--plugin' option[m
[32m+[m[32m// for the GCC compiler[m
[32m+[m[32mCMAKE_CXX_COMPILER_RANLIB:FILEPATH=/usr/bin/gcc-ranlib-7[m
[32m+[m
[32m+[m[32m//Flags used by the CXX compiler during all build types.[m
[32m+[m[32mCMAKE_CXX_FLAGS:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the CXX compiler during DEBUG builds.[m
[32m+[m[32mCMAKE_CXX_FLAGS_DEBUG:STRING=-g[m
[32m+[m
[32m+[m[32m//Flags used by the CXX compiler during MINSIZEREL builds.[m
[32m+[m[32mCMAKE_CXX_FLAGS_MINSIZEREL:STRING=-Os -DNDEBUG[m
[32m+[m
[32m+[m[32m//Flags used by the CXX compiler during RELEASE builds.[m
[32m+[m[32mCMAKE_CXX_FLAGS_RELEASE:STRING=-O3 -DNDEBUG[m
[32m+[m
[32m+[m[32m//Flags used by the CXX compiler during RELWITHDEBINFO builds.[m
[32m+[m[32mCMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=-O2 -g -DNDEBUG[m
[32m+[m
[32m+[m[32m//C compiler[m
[32m+[m[32mCMAKE_C_COMPILER:FILEPATH=/usr/bin/cc[m
[32m+[m
[32m+[m[32m//A wrapper around 'ar' adding the appropriate '--plugin' option[m
[32m+[m[32m// for the GCC compiler[m
[32m+[m[32mCMAKE_C_COMPILER_AR:FILEPATH=/usr/bin/gcc-ar-7[m
[32m+[m
[32m+[m[32m//A wrapper around 'ranlib' adding the appropriate '--plugin' option[m
[32m+[m[32m// for the GCC compiler[m
[32m+[m[32mCMAKE_C_COMPILER_RANLIB:FILEPATH=/usr/bin/gcc-ranlib-7[m
[32m+[m
[32m+[m[32m//Flags used by the C compiler during all build types.[m
[32m+[m[32mCMAKE_C_FLAGS:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the C compiler during DEBUG builds.[m
[32m+[m[32mCMAKE_C_FLAGS_DEBUG:STRING=-g[m
[32m+[m
[32m+[m[32m//Flags used by the C compiler during MINSIZEREL builds.[m
[32m+[m[32mCMAKE_C_FLAGS_MINSIZEREL:STRING=-Os -DNDEBUG[m
[32m+[m
[32m+[m[32m//Flags used by the C compiler during RELEASE builds.[m
[32m+[m[32mCMAKE_C_FLAGS_RELEASE:STRING=-O3 -DNDEBUG[m
[32m+[m
[32m+[m[32m//Flags used by the C compiler during RELWITHDEBINFO builds.[m
[32m+[m[32mCMAKE_C_FLAGS_RELWITHDEBINFO:STRING=-O2 -g -DNDEBUG[m
[32m+[m
[32m+[m[32m//Flags used by the linker during all build types.[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during DEBUG builds.[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_DEBUG:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during MINSIZEREL builds.[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_MINSIZEREL:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during RELEASE builds.[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_RELEASE:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during RELWITHDEBINFO builds.[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO:STRING=[m
[32m+[m
[32m+[m[32m//Enable/Disable output of compile commands during generation.[m
[32m+[m[32mCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=OFF[m
[32m+[m
[32m+[m[32m//Install path prefix, prepended onto install directories.[m
[32m+[m[32mCMAKE_INSTALL_PREFIX:PATH=/usr/local[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_LINKER:FILEPATH=/usr/bin/ld[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_MAKE_PROGRAM:FILEPATH=/usr/bin/make[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of modules during[m
[32m+[m[32m// all build types.[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of modules during[m
[32m+[m[32m// DEBUG builds.[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_DEBUG:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of modules during[m
[32m+[m[32m// MINSIZEREL builds.[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_MINSIZEREL:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of modules during[m
[32m+[m[32m// RELEASE builds.[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_RELEASE:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of modules during[m
[32m+[m[32m// RELWITHDEBINFO builds.[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO:STRING=[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_NM:FILEPATH=/usr/bin/nm[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_OBJCOPY:FILEPATH=/usr/bin/objcopy[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_OBJDUMP:FILEPATH=/usr/bin/objdump[m
[32m+[m
[32m+[m[32m//Value Computed by CMake[m
[32m+[m[32mCMAKE_PROJECT_DESCRIPTION:STATIC=[m
[32m+[m
[32m+[m[32m//Value Computed by CMake[m
[32m+[m[32mCMAKE_PROJECT_HOMEPAGE_URL:STATIC=[m
[32m+[m
[32m+[m[32m//Value Computed by CMake[m
[32m+[m[32mCMAKE_PROJECT_NAME:STATIC=Project[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_RANLIB:FILEPATH=/usr/bin/ranlib[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of shared libraries[m
[32m+[m[32m// during all build types.[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of shared libraries[m
[32m+[m[32m// during DEBUG builds.[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_DEBUG:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of shared libraries[m
[32m+[m[32m// during MINSIZEREL builds.[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_MINSIZEREL:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of shared libraries[m
[32m+[m[32m// during RELEASE builds.[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_RELEASE:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of shared libraries[m
[32m+[m[32m// during RELWITHDEBINFO builds.[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO:STRING=[m
[32m+[m
[32m+[m[32m//If set, runtime paths are not added when installing shared libraries,[m
[32m+[m[32m// but are added when building.[m
[32m+[m[32mCMAKE_SKIP_INSTALL_RPATH:BOOL=NO[m
[32m+[m
[32m+[m[32m//If set, runtime paths are not added when using shared libraries.[m
[32m+[m[32mCMAKE_SKIP_RPATH:BOOL=NO[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of static libraries[m
[32m+[m[32m// during all build types.[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of static libraries[m
[32m+[m[32m// during DEBUG builds.[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_DEBUG:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of static libraries[m
[32m+[m[32m// during MINSIZEREL builds.[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_MINSIZEREL:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of static libraries[m
[32m+[m[32m// during RELEASE builds.[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_RELEASE:STRING=[m
[32m+[m
[32m+[m[32m//Flags used by the linker during the creation of static libraries[m
[32m+[m[32m// during RELWITHDEBINFO builds.[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO:STRING=[m
[32m+[m
[32m+[m[32m//Path to a program.[m
[32m+[m[32mCMAKE_STRIP:FILEPATH=/usr/bin/strip[m
[32m+[m
[32m+[m[32m//If this value is on, makefiles will be generated without the[m
[32m+[m[32m// .SILENT directive, and all commands will be echoed to the console[m
[32m+[m[32m// during the make.  This is useful for debugging only. With Visual[m
[32m+[m[32m// Studio IDE projects all commands are done without /nologo.[m
[32m+[m[32mCMAKE_VERBOSE_MAKEFILE:BOOL=FALSE[m
[32m+[m
[32m+[m[32m//Value Computed by CMake[m
[32m+[m[32mProject_BINARY_DIR:STATIC=/chos/kernel/mm[m
[32m+[m
[32m+[m[32m//Value Computed by CMake[m
[32m+[m[32mProject_SOURCE_DIR:STATIC=/chos/kernel/mm[m
[32m+[m
[32m+[m
[32m+[m[32m########################[m
[32m+[m[32m# INTERNAL cache entries[m
[32m+[m[32m########################[m
[32m+[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_AR[m
[32m+[m[32mCMAKE_AR-ADVANCED:INTERNAL=1[m
[32m+[m[32m//This is the directory where this CMakeCache.txt was created[m
[32m+[m[32mCMAKE_CACHEFILE_DIR:INTERNAL=/chos/kernel/mm[m
[32m+[m[32m//Major version of cmake used to create the current loaded cache[m
[32m+[m[32mCMAKE_CACHE_MAJOR_VERSION:INTERNAL=3[m
[32m+[m[32m//Minor version of cmake used to create the current loaded cache[m
[32m+[m[32mCMAKE_CACHE_MINOR_VERSION:INTERNAL=15[m
[32m+[m[32m//Patch version of cmake used to create the current loaded cache[m
[32m+[m[32mCMAKE_CACHE_PATCH_VERSION:INTERNAL=5[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_COLOR_MAKEFILE[m
[32m+[m[32mCMAKE_COLOR_MAKEFILE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//Path to CMake executable.[m
[32m+[m[32mCMAKE_COMMAND:INTERNAL=/usr/local/bin/cmake[m
[32m+[m[32m//Path to cpack program executable.[m
[32m+[m[32mCMAKE_CPACK_COMMAND:INTERNAL=/usr/local/bin/cpack[m
[32m+[m[32m//Path to ctest program executable.[m
[32m+[m[32mCMAKE_CTEST_COMMAND:INTERNAL=/usr/local/bin/ctest[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_COMPILER[m
[32m+[m[32mCMAKE_CXX_COMPILER-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_COMPILER_AR[m
[32m+[m[32mCMAKE_CXX_COMPILER_AR-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_COMPILER_RANLIB[m
[32m+[m[32mCMAKE_CXX_COMPILER_RANLIB-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_FLAGS[m
[32m+[m[32mCMAKE_CXX_FLAGS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_FLAGS_DEBUG[m
[32m+[m[32mCMAKE_CXX_FLAGS_DEBUG-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_FLAGS_MINSIZEREL[m
[32m+[m[32mCMAKE_CXX_FLAGS_MINSIZEREL-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_FLAGS_RELEASE[m
[32m+[m[32mCMAKE_CXX_FLAGS_RELEASE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_CXX_FLAGS_RELWITHDEBINFO[m
[32m+[m[32mCMAKE_CXX_FLAGS_RELWITHDEBINFO-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_COMPILER[m
[32m+[m[32mCMAKE_C_COMPILER-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_COMPILER_AR[m
[32m+[m[32mCMAKE_C_COMPILER_AR-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_COMPILER_RANLIB[m
[32m+[m[32mCMAKE_C_COMPILER_RANLIB-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_FLAGS[m
[32m+[m[32mCMAKE_C_FLAGS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_FLAGS_DEBUG[m
[32m+[m[32mCMAKE_C_FLAGS_DEBUG-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_FLAGS_MINSIZEREL[m
[32m+[m[32mCMAKE_C_FLAGS_MINSIZEREL-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_FLAGS_RELEASE[m
[32m+[m[32mCMAKE_C_FLAGS_RELEASE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_C_FLAGS_RELWITHDEBINFO[m
[32m+[m[32mCMAKE_C_FLAGS_RELWITHDEBINFO-ADVANCED:INTERNAL=1[m
[32m+[m[32m//Executable file format[m
[32m+[m[32mCMAKE_EXECUTABLE_FORMAT:INTERNAL=ELF[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_EXE_LINKER_FLAGS[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_EXE_LINKER_FLAGS_DEBUG[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_DEBUG-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_EXE_LINKER_FLAGS_MINSIZEREL[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_MINSIZEREL-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_EXE_LINKER_FLAGS_RELEASE[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_RELEASE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO[m
[32m+[m[32mCMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_EXPORT_COMPILE_COMMANDS[m
[32m+[m[32mCMAKE_EXPORT_COMPILE_COMMANDS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//Name of external makefile project generator.[m
[32m+[m[32mCMAKE_EXTRA_GENERATOR:INTERNAL=[m
[32m+[m[32m//Name of generator.[m
[32m+[m[32mCMAKE_GENERATOR:INTERNAL=Unix Makefiles[m
[32m+[m[32m//Generator instance identifier.[m
[32m+[m[32mCMAKE_GENERATOR_INSTANCE:INTERNAL=[m
[32m+[m[32m//Name of generator platform.[m
[32m+[m[32mCMAKE_GENERATOR_PLATFORM:INTERNAL=[m
[32m+[m[32m//Name of generator toolset.[m
[32m+[m[32mCMAKE_GENERATOR_TOOLSET:INTERNAL=[m
[32m+[m[32m//Source directory with the top level CMakeLists.txt file for this[m
[32m+[m[32m// project[m
[32m+[m[32mCMAKE_HOME_DIRECTORY:INTERNAL=/chos/kernel/mm[m
[32m+[m[32m//Install .so files without execute permission.[m
[32m+[m[32mCMAKE_INSTALL_SO_NO_EXE:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_LINKER[m
[32m+[m[32mCMAKE_LINKER-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_MAKE_PROGRAM[m
[32m+[m[32mCMAKE_MAKE_PROGRAM-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_MODULE_LINKER_FLAGS[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_MODULE_LINKER_FLAGS_DEBUG[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_DEBUG-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_MODULE_LINKER_FLAGS_MINSIZEREL[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_MINSIZEREL-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_MODULE_LINKER_FLAGS_RELEASE[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_RELEASE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO[m
[32m+[m[32mCMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_NM[m
[32m+[m[32mCMAKE_NM-ADVANCED:INTERNAL=1[m
[32m+[m[32m//number of local generators[m
[32m+[m[32mCMAKE_NUMBER_OF_MAKEFILES:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_OBJCOPY[m
[32m+[m[32mCMAKE_OBJCOPY-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_OBJDUMP[m
[32m+[m[32mCMAKE_OBJDUMP-ADVANCED:INTERNAL=1[m
[32m+[m[32m//Platform information initialized[m
[32m+[m[32mCMAKE_PLATFORM_INFO_INITIALIZED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_RANLIB[m
[32m+[m[32mCMAKE_RANLIB-ADVANCED:INTERNAL=1[m
[32m+[m[32m//Path to CMake installation.[m
[32m+[m[32mCMAKE_ROOT:INTERNAL=/usr/local/share/cmake-3.15[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SHARED_LINKER_FLAGS[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SHARED_LINKER_FLAGS_DEBUG[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_DEBUG-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_MINSIZEREL-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SHARED_LINKER_FLAGS_RELEASE[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_RELEASE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO[m
[32m+[m[32mCMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SKIP_INSTALL_RPATH[m
[32m+[m[32mCMAKE_SKIP_INSTALL_RPATH-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_SKIP_RPATH[m
[32m+[m[32mCMAKE_SKIP_RPATH-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_STATIC_LINKER_FLAGS[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_STATIC_LINKER_FLAGS_DEBUG[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_DEBUG-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_STATIC_LINKER_FLAGS_MINSIZEREL[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_MINSIZEREL-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_STATIC_LINKER_FLAGS_RELEASE[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_RELEASE-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO[m
[32m+[m[32mCMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO-ADVANCED:INTERNAL=1[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_STRIP[m
[32m+[m[32mCMAKE_STRIP-ADVANCED:INTERNAL=1[m
[32m+[m[32m//uname command[m
[32m+[m[32mCMAKE_UNAME:INTERNAL=/bin/uname[m
[32m+[m[32m//ADVANCED property for variable: CMAKE_VERBOSE_MAKEFILE[m
[32m+[m[32mCMAKE_VERBOSE_MAKEFILE-ADVANCED:INTERNAL=1[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/3.15.5/CMakeCCompiler.cmake b/kernel/mm/CMakeFiles/3.15.5/CMakeCCompiler.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..923ea1d[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/3.15.5/CMakeCCompiler.cmake[m
[36m@@ -0,0 +1,76 @@[m
[32m+[m[32mset(CMAKE_C_COMPILER "/usr/bin/cc")[m
[32m+[m[32mset(CMAKE_C_COMPILER_ARG1 "")[m
[32m+[m[32mset(CMAKE_C_COMPILER_ID "GNU")[m
[32m+[m[32mset(CMAKE_C_COMPILER_VERSION "7.4.0")[m
[32m+[m[32mset(CMAKE_C_COMPILER_VERSION_INTERNAL "")[m
[32m+[m[32mset(CMAKE_C_COMPILER_WRAPPER "")[m
[32m+[m[32mset(CMAKE_C_STANDARD_COMPUTED_DEFAULT "11")[m
[32m+[m[32mset(CMAKE_C_COMPILE_FEATURES "c_std_90;c_function_prototypes;c_std_99;c_restrict;c_variadic_macros;c_std_11;c_static_assert")[m
[32m+[m[32mset(CMAKE_C90_COMPILE_FEATURES "c_std_90;c_function_prototypes")[m
[32m+[m[32mset(CMAKE_C99_COMPILE_FEATURES "c_std_99;c_restrict;c_variadic_macros")[m
[32m+[m[32mset(CMAKE_C11_COMPILE_FEATURES "c_std_11;c_static_assert")[m
[32m+[m
[32m+[m[32mset(CMAKE_C_PLATFORM_ID "Linux")[m
[32m+[m[32mset(CMAKE_C_SIMULATE_ID "")[m
[32m+[m[32mset(CMAKE_C_COMPILER_FRONTEND_VARIANT "")[m
[32m+[m[32mset(CMAKE_C_SIMULATE_VERSION "")[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mset(CMAKE_AR "/usr/bin/ar")[m
[32m+[m[32mset(CMAKE_C_COMPILER_AR "/usr/bin/gcc-ar-7")[m
[32m+[m[32mset(CMAKE_RANLIB "/usr/bin/ranlib")[m
[32m+[m[32mset(CMAKE_C_COMPILER_RANLIB "/usr/bin/gcc-ranlib-7")[m
[32m+[m[32mset(CMAKE_LINKER "/usr/bin/ld")[m
[32m+[m[32mset(CMAKE_MT "")[m
[32m+[m[32mset(CMAKE_COMPILER_IS_GNUCC 1)[m
[32m+[m[32mset(CMAKE_C_COMPILER_LOADED 1)[m
[32m+[m[32mset(CMAKE_C_COMPILER_WORKS TRUE)[m
[32m+[m[32mset(CMAKE_C_ABI_COMPILED TRUE)[m
[32m+[m[32mset(CMAKE_COMPILER_IS_MINGW )[m
[32m+[m[32mset(CMAKE_COMPILER_IS_CYGWIN )[m
[32m+[m[32mif(CMAKE_COMPILER_IS_CYGWIN)[m
[32m+[m[32m  set(CYGWIN 1)[m
[32m+[m[32m  set(UNIX 1)[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mset(CMAKE_C_COMPILER_ENV_VAR "CC")[m
[32m+[m
[32m+[m[32mif(CMAKE_COMPILER_IS_MINGW)[m
[32m+[m[32m  set(MINGW 1)[m
[32m+[m[32mendif()[m
[32m+[m[32mset(CMAKE_C_COMPILER_ID_RUN 1)[m
[32m+[m[32mset(CMAKE_C_SOURCE_FILE_EXTENSIONS c;m)[m
[32m+[m[32mset(CMAKE_C_IGNORE_EXTENSIONS h;H;o;O;obj;OBJ;def;DEF;rc;RC)[m
[32m+[m[32mset(CMAKE_C_LINKER_PREFERENCE 10)[m
[32m+[m
[32m+[m[32m# Save compiler ABI information.[m
[32m+[m[32mset(CMAKE_C_SIZEOF_DATA_PTR "8")[m
[32m+[m[32mset(CMAKE_C_COMPILER_ABI "ELF")[m
[32m+[m[32mset(CMAKE_C_LIBRARY_ARCHITECTURE "x86_64-linux-gnu")[m
[32m+[m
[32m+[m[32mif(CMAKE_C_SIZEOF_DATA_PTR)[m
[32m+[m[32m  set(CMAKE_SIZEOF_VOID_P "${CMAKE_C_SIZEOF_DATA_PTR}")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mif(CMAKE_C_COMPILER_ABI)[m
[32m+[m[32m  set(CMAKE_INTERNAL_PLATFORM_ABI "${CMAKE_C_COMPILER_ABI}")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mif(CMAKE_C_LIBRARY_ARCHITECTURE)[m
[32m+[m[32m  set(CMAKE_LIBRARY_ARCHITECTURE "x86_64-linux-gnu")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mset(CMAKE_C_CL_SHOWINCLUDES_PREFIX "")[m
[32m+[m[32mif(CMAKE_C_CL_SHOWINCLUDES_PREFIX)[m
[32m+[m[32m  set(CMAKE_CL_SHOWINCLUDES_PREFIX "${CMAKE_C_CL_SHOWINCLUDES_PREFIX}")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mset(CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES "/usr/lib/gcc/x86_64-linux-gnu/7/include;/usr/local/include;/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed;/usr/include/x86_64-linux-gnu;/usr/include")[m
[32m+[m[32mset(CMAKE_C_IMPLICIT_LINK_LIBRARIES "gcc;gcc_s;c;gcc;gcc_s")[m
[32m+[m[32mset(CMAKE_C_IMPLICIT_LINK_DIRECTORIES "/usr/lib/gcc/x86_64-linux-gnu/7;/usr/lib/x86_64-linux-gnu;/usr/lib;/lib/x86_64-linux-gnu;/lib")[m
[32m+[m[32mset(CMAKE_C_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES "")[m
[1mdiff --git a/kernel/mm/CMakeFiles/3.15.5/CMakeCXXCompiler.cmake b/kernel/mm/CMakeFiles/3.15.5/CMakeCXXCompiler.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..32ddf21[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/3.15.5/CMakeCXXCompiler.cmake[m
[36m@@ -0,0 +1,79 @@[m
[32m+[m[32mset(CMAKE_CXX_COMPILER "/usr/bin/c++")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_ARG1 "")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_ID "GNU")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_VERSION "7.4.0")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_VERSION_INTERNAL "")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_WRAPPER "")[m
[32m+[m[32mset(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT "14")[m
[32m+[m[32mset(CMAKE_CXX_COMPILE_FEATURES "cxx_std_98;cxx_template_template_parameters;cxx_std_11;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates;cxx_std_14;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates;cxx_std_17")[m
[32m+[m[32mset(CMAKE_CXX98_COMPILE_FEATURES "cxx_std_98;cxx_template_template_parameters")[m
[32m+[m[32mset(CMAKE_CXX11_COMPILE_FEATURES "cxx_std_11;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates")[m
[32m+[m[32mset(CMAKE_CXX14_COMPILE_FEATURES "cxx_std_14;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates")[m
[32m+[m[32mset(CMAKE_CXX17_COMPILE_FEATURES "cxx_std_17")[m
[32m+[m[32mset(CMAKE_CXX20_COMPILE_FEATURES "")[m
[32m+[m
[32m+[m[32mset(CMAKE_CXX_PLATFORM_ID "Linux")[m
[32m+[m[32mset(CMAKE_CXX_SIMULATE_ID "")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_FRONTEND_VARIANT "")[m
[32m+[m[32mset(CMAKE_CXX_SIMULATE_VERSION "")[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mset(CMAKE_AR "/usr/bin/ar")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_AR "/usr/bin/gcc-ar-7")[m
[32m+[m[32mset(CMAKE_RANLIB "/usr/bin/ranlib")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_RANLIB "/usr/bin/gcc-ranlib-7")[m
[32m+[m[32mset(CMAKE_LINKER "/usr/bin/ld")[m
[32m+[m[32mset(CMAKE_MT "")[m
[32m+[m[32mset(CMAKE_COMPILER_IS_GNUCXX 1)[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_LOADED 1)[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_WORKS TRUE)[m
[32m+[m[32mset(CMAKE_CXX_ABI_COMPILED TRUE)[m
[32m+[m[32mset(CMAKE_COMPILER_IS_MINGW )[m
[32m+[m[32mset(CMAKE_COMPILER_IS_CYGWIN )[m
[32m+[m[32mif(CMAKE_COMPILER_IS_CYGWIN)[m
[32m+[m[32m  set(CYGWIN 1)[m
[32m+[m[32m  set(UNIX 1)[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_ENV_VAR "CXX")[m
[32m+[m
[32m+[m[32mif(CMAKE_COMPILER_IS_MINGW)[m
[32m+[m[32m  set(MINGW 1)[m
[32m+[m[32mendif()[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_ID_RUN 1)[m
[32m+[m[32mset(CMAKE_CXX_IGNORE_EXTENSIONS inl;h;hpp;HPP;H;o;O;obj;OBJ;def;DEF;rc;RC)[m
[32m+[m[32mset(CMAKE_CXX_SOURCE_FILE_EXTENSIONS C;M;c++;cc;cpp;cxx;mm;CPP)[m
[32m+[m[32mset(CMAKE_CXX_LINKER_PREFERENCE 30)[m
[32m+[m[32mset(CMAKE_CXX_LINKER_PREFERENCE_PROPAGATES 1)[m
[32m+[m
[32m+[m[32m# Save compiler ABI information.[m
[32m+[m[32mset(CMAKE_CXX_SIZEOF_DATA_PTR "8")[m
[32m+[m[32mset(CMAKE_CXX_COMPILER_ABI "ELF")[m
[32m+[m[32mset(CMAKE_CXX_LIBRARY_ARCHITECTURE "x86_64-linux-gnu")[m
[32m+[m
[32m+[m[32mif(CMAKE_CXX_SIZEOF_DATA_PTR)[m
[32m+[m[32m  set(CMAKE_SIZEOF_VOID_P "${CMAKE_CXX_SIZEOF_DATA_PTR}")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mif(CMAKE_CXX_COMPILER_ABI)[m
[32m+[m[32m  set(CMAKE_INTERNAL_PLATFORM_ABI "${CMAKE_CXX_COMPILER_ABI}")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mif(CMAKE_CXX_LIBRARY_ARCHITECTURE)[m
[32m+[m[32m  set(CMAKE_LIBRARY_ARCHITECTURE "x86_64-linux-gnu")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mset(CMAKE_CXX_CL_SHOWINCLUDES_PREFIX "")[m
[32m+[m[32mif(CMAKE_CXX_CL_SHOWINCLUDES_PREFIX)[m
[32m+[m[32m  set(CMAKE_CL_SHOWINCLUDES_PREFIX "${CMAKE_CXX_CL_SHOWINCLUDES_PREFIX}")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mset(CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES "/usr/include/c++/7;/usr/include/x86_64-linux-gnu/c++/7;/usr/include/c++/7/backward;/usr/lib/gcc/x86_64-linux-gnu/7/include;/usr/local/include;/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed;/usr/include/x86_64-linux-gnu;/usr/include")[m
[32m+[m[32mset(CMAKE_CXX_IMPLICIT_LINK_LIBRARIES "stdc++;m;gcc_s;gcc;c;gcc_s;gcc")[m
[32m+[m[32mset(CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES "/usr/lib/gcc/x86_64-linux-gnu/7;/usr/lib/x86_64-linux-gnu;/usr/lib;/lib/x86_64-linux-gnu;/lib")[m
[32m+[m[32mset(CMAKE_CXX_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES "")[m
[1mdiff --git a/kernel/mm/CMakeFiles/3.15.5/CMakeSystem.cmake b/kernel/mm/CMakeFiles/3.15.5/CMakeSystem.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..50252a2[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/3.15.5/CMakeSystem.cmake[m
[36m@@ -0,0 +1,15 @@[m
[32m+[m[32mset(CMAKE_HOST_SYSTEM "Linux-5.0.0-23-generic")[m
[32m+[m[32mset(CMAKE_HOST_SYSTEM_NAME "Linux")[m
[32m+[m[32mset(CMAKE_HOST_SYSTEM_VERSION "5.0.0-23-generic")[m
[32m+[m[32mset(CMAKE_HOST_SYSTEM_PROCESSOR "x86_64")[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mset(CMAKE_SYSTEM "Linux-5.0.0-23-generic")[m
[32m+[m[32mset(CMAKE_SYSTEM_NAME "Linux")[m
[32m+[m[32mset(CMAKE_SYSTEM_VERSION "5.0.0-23-generic")[m
[32m+[m[32mset(CMAKE_SYSTEM_PROCESSOR "x86_64")[m
[32m+[m
[32m+[m[32mset(CMAKE_CROSSCOMPILING "FALSE")[m
[32m+[m
[32m+[m[32mset(CMAKE_SYSTEM_LOADED 1)[m
[1mdiff --git a/kernel/mm/CMakeFiles/3.15.5/CompilerIdC/CMakeCCompilerId.c b/kernel/mm/CMakeFiles/3.15.5/CompilerIdC/CMakeCCompilerId.c[m
[1mnew file mode 100644[m
[1mindex 0000000..917e8b9[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/3.15.5/CompilerIdC/CMakeCCompilerId.c[m
[36m@@ -0,0 +1,665 @@[m
[32m+[m[32m#ifdef __cplusplus[m
[32m+[m[32m# error "A C++ compiler has been selected for C."[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#if defined(__18CXX)[m
[32m+[m[32m# define ID_VOID_MAIN[m
[32m+[m[32m#endif[m
[32m+[m[32m#if defined(__CLASSIC_C__)[m
[32m+[m[32m/* cv-qualifiers did not exist in K&R C */[m
[32m+[m[32m# define const[m
[32m+[m[32m# define volatile[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m
[32m+[m[32m/* Version number components: V=Version, R=Revision, P=Patch[m
[32m+[m[32m   Version date components:   YYYY=Year, MM=Month,   DD=Day  */[m
[32m+[m
[32m+[m[32m#if defined(__INTEL_COMPILER) || defined(__ICC)[m
[32m+[m[32m# define COMPILER_ID "Intel"[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m#  define SIMULATE_ID "MSVC"[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC__)[m
[32m+[m[32m#  define SIMULATE_ID "GNU"[m
[32m+[m[32m# endif[m
[32m+[m[32m  /* __INTEL_COMPILER = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__INTEL_COMPILER/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__INTEL_COMPILER/10 % 10)[m
[32m+[m[32m# if defined(__INTEL_COMPILER_UPDATE)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__INTEL_COMPILER_UPDATE)[m
[32m+[m[32m# else[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__INTEL_COMPILER   % 10)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__INTEL_COMPILER_BUILD_DATE)[m
[32m+[m[32m  /* __INTEL_COMPILER_BUILD_DATE = YYYYMMDD */[m
[32m+[m[32m#  define COMPILER_VERSION_TWEAK DEC(__INTEL_COMPILER_BUILD_DATE)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m   /* _MSC_VER = VVRR */[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC__)[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(__GNUC__)[m
[32m+[m[32m# elif defined(__GNUG__)[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(__GNUG__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_MINOR__)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(__GNUC_MINOR__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m#  define SIMULATE_VERSION_PATCH DEC(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__PATHCC__)[m
[32m+[m[32m# define COMPILER_ID "PathScale"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__PATHCC__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__PATHCC_MINOR__)[m
[32m+[m[32m# if defined(__PATHCC_PATCHLEVEL__)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__PATHCC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__BORLANDC__) && defined(__CODEGEARC_VERSION__)[m
[32m+[m[32m# define COMPILER_ID "Embarcadero"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR HEX(__CODEGEARC_VERSION__>>24 & 0x00FF)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR HEX(__CODEGEARC_VERSION__>>16 & 0x00FF)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__CODEGEARC_VERSION__     & 0xFFFF)[m
[32m+[m
[32m+[m[32m#elif defined(__BORLANDC__)[m
[32m+[m[32m# define COMPILER_ID "Borland"[m
[32m+[m[32m  /* __BORLANDC__ = 0xVRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR HEX(__BORLANDC__>>8)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR HEX(__BORLANDC__ & 0xFF)[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__) && __WATCOMC__ < 1200[m
[32m+[m[32m# define COMPILER_ID "Watcom"[m
[32m+[m[32m   /* __WATCOMC__ = VVRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__WATCOMC__ / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC((__WATCOMC__ / 10) % 10)[m
[32m+[m[32m# if (__WATCOMC__ % 10) > 0[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__WATCOMC__ % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__)[m
[32m+[m[32m# define COMPILER_ID "OpenWatcom"[m
[32m+[m[32m   /* __WATCOMC__ = VVRP + 1100 */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC((__WATCOMC__ - 1100) / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC((__WATCOMC__ / 10) % 10)[m
[32m+[m[32m# if (__WATCOMC__ % 10) > 0[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__WATCOMC__ % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__SUNPRO_C)[m
[32m+[m[32m# define COMPILER_ID "SunPro"[m
[32m+[m[32m# if __SUNPRO_C >= 0x5100[m
[32m+[m[32m   /* __SUNPRO_C = 0xVRRP */[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR HEX(__SUNPRO_C>>12)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR HEX(__SUNPRO_C>>4 & 0xFF)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH HEX(__SUNPRO_C    & 0xF)[m
[32m+[m[32m# else[m
[32m+[m[32m   /* __SUNPRO_CC = 0xVRP */[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR HEX(__SUNPRO_C>>8)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR HEX(__SUNPRO_C>>4 & 0xF)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH HEX(__SUNPRO_C    & 0xF)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__HP_cc)[m
[32m+[m[32m# define COMPILER_ID "HP"[m
[32m+[m[32m  /* __HP_cc = VVRRPP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__HP_cc/10000)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__HP_cc/100 % 100)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__HP_cc     % 100)[m
[32m+[m
[32m+[m[32m#elif defined(__DECC)[m
[32m+[m[32m# define COMPILER_ID "Compaq"[m
[32m+[m[32m  /* __DECC_VER = VVRRTPPPP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__DECC_VER/10000000)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__DECC_VER/100000  % 100)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__DECC_VER         % 10000)[m
[32m+[m
[32m+[m[32m#elif defined(__IBMC__) && defined(__COMPILER_VER__)[m
[32m+[m[32m# define COMPILER_ID "zOS"[m
[32m+[m[32m  /* __IBMC__ = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__IBMC__/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__IBMC__/10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__IBMC__    % 10)[m
[32m+[m
[32m+[m[32m#elif defined(__ibmxl__) && defined(__clang__)[m
[32m+[m[32m# define COMPILER_ID "XLClang"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__ibmxl_version__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__ibmxl_release__)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__ibmxl_modification__)[m
[32m+[m[32m# define COMPILER_VERSION_TWEAK DEC(__ibmxl_ptf_fix_level__)[m
[32m+[m
[32m+[m
[32m+[m[32m#elif defined(__IBMC__) && !defined(__COMPILER_VER__) && __IBMC__ >= 800[m
[32m+[m[32m# define COMPILER_ID "XL"[m
[32m+[m[32m  /* __IBMC__ = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__IBMC__/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__IBMC__/10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__IBMC__    % 10)[m
[32m+[m
[32m+[m[32m#elif defined(__IBMC__) && !defined(__COMPILER_VER__) && __IBMC__ < 800[m
[32m+[m[32m# define COMPILER_ID "VisualAge"[m
[32m+[m[32m  /* __IBMC__ = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__IBMC__/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__IBMC__/10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__IBMC__    % 10)[m
[32m+[m
[32m+[m[32m#elif defined(__PGI)[m
[32m+[m[32m# define COMPILER_ID "PGI"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__PGIC__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__PGIC_MINOR__)[m
[32m+[m[32m# if defined(__PGIC_PATCHLEVEL__)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__PGIC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(_CRAYC)[m
[32m+[m[32m# define COMPILER_ID "Cray"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(_RELEASE_MAJOR)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(_RELEASE_MINOR)[m
[32m+[m
[32m+[m[32m#elif defined(__TI_COMPILER_VERSION__)[m
[32m+[m[32m# define COMPILER_ID "TI"[m
[32m+[m[32m  /* __TI_COMPILER_VERSION__ = VVVRRRPPP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__TI_COMPILER_VERSION__/1000000)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__TI_COMPILER_VERSION__/1000   % 1000)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__TI_COMPILER_VERSION__        % 1000)[m
[32m+[m
[32m+[m[32m#elif defined(__FUJITSU) || defined(__FCC_VERSION) || defined(__fcc_version)[m
[32m+[m[32m# define COMPILER_ID "Fujitsu"[m
[32m+[m
[32m+[m[32m#elif defined(__ghs__)[m
[32m+[m[32m# define COMPILER_ID "GHS"[m
[32m+[m[32m/* __GHS_VERSION_NUMBER = VVVVRP */[m
[32m+[m[32m# ifdef __GHS_VERSION_NUMBER[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__GHS_VERSION_NUMBER / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__GHS_VERSION_NUMBER / 10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__GHS_VERSION_NUMBER      % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__TINYC__)[m
[32m+[m[32m# define COMPILER_ID "TinyCC"[m
[32m+[m
[32m+[m[32m#elif defined(__BCC__)[m
[32m+[m[32m# define COMPILER_ID "Bruce"[m
[32m+[m
[32m+[m[32m#elif defined(__SCO_VERSION__)[m
[32m+[m[32m# define COMPILER_ID "SCO"[m
[32m+[m
[32m+[m[32m#elif defined(__ARMCC_VERSION) && !defined(__clang__)[m
[32m+[m[32m# define COMPILER_ID "ARMCC"[m
[32m+[m[32m#if __ARMCC_VERSION >= 1000000[m
[32m+[m[32m  /* __ARMCC_VERSION = VRRPPPP */[m
[32m+[m[32m  # define COMPILER_VERSION_MAJOR DEC(__ARMCC_VERSION/1000000)[m
[32m+[m[32m  # define COMPILER_VERSION_MINOR DEC(__ARMCC_VERSION/10000 % 100)[m
[32m+[m[32m  # define COMPILER_VERSION_PATCH DEC(__ARMCC_VERSION     % 10000)[m
[32m+[m[32m#else[m
[32m+[m[32m  /* __ARMCC_VERSION = VRPPPP */[m
[32m+[m[32m  # define COMPILER_VERSION_MAJOR DEC(__ARMCC_VERSION/100000)[m
[32m+[m[32m  # define COMPILER_VERSION_MINOR DEC(__ARMCC_VERSION/10000 % 10)[m
[32m+[m[32m  # define COMPILER_VERSION_PATCH DEC(__ARMCC_VERSION    % 10000)[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m
[32m+[m[32m#elif defined(__clang__) && defined(__apple_build_version__)[m
[32m+[m[32m# define COMPILER_ID "AppleClang"[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m#  define SIMULATE_ID "MSVC"[m
[32m+[m[32m# endif[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__clang_major__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__clang_minor__)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__clang_patchlevel__)[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m   /* _MSC_VER = VVRR */[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# endif[m
[32m+[m[32m# define COMPILER_VERSION_TWEAK DEC(__apple_build_version__)[m
[32m+[m
[32m+[m[32m#elif defined(__clang__) && defined(__ARMCOMPILER_VERSION)[m
[32m+[m[32m# define COMPILER_ID "ARMClang"[m
[32m+[m[32m  # define COMPILER_VERSION_MAJOR DEC(__ARMCOMPILER_VERSION/1000000)[m
[32m+[m[32m  # define COMPILER_VERSION_MINOR DEC(__ARMCOMPILER_VERSION/10000 % 100)[m
[32m+[m[32m  # define COMPILER_VERSION_PATCH DEC(__ARMCOMPILER_VERSION     % 10000)[m
[32m+[m[32m# define COMPILER_VERSION_INTERNAL DEC(__ARMCOMPILER_VERSION)[m
[32m+[m
[32m+[m[32m#elif defined(__clang__)[m
[32m+[m[32m# define COMPILER_ID "Clang"[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m#  define SIMULATE_ID "MSVC"[m
[32m+[m[32m# endif[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__clang_major__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__clang_minor__)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__clang_patchlevel__)[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m   /* _MSC_VER = VVRR */[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__GNUC__)[m
[32m+[m[32m# define COMPILER_ID "GNU"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__GNUC__)[m
[32m+[m[32m# if defined(__GNUC_MINOR__)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC(__GNUC_MINOR__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(_MSC_VER)[m
[32m+[m[32m# define COMPILER_ID "MSVC"[m
[32m+[m[32m  /* _MSC_VER = VVRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# if defined(_MSC_FULL_VER)[m
[32m+[m[32m#  if _MSC_VER >= 1400[m
[32m+[m[32m    /* _MSC_FULL_VER = VVRRPPPPP */[m
[32m+[m[32m#   define COMPILER_VERSION_PATCH DEC(_MSC_FULL_VER % 100000)[m
[32m+[m[32m#  else[m
[32m+[m[32m    /* _MSC_FULL_VER = VVRRPPPP */[m
[32m+[m[32m#   define COMPILER_VERSION_PATCH DEC(_MSC_FULL_VER % 10000)[m
[32m+[m[32m#  endif[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(_MSC_BUILD)[m
[32m+[m[32m#  define COMPILER_VERSION_TWEAK DEC(_MSC_BUILD)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__VISUALDSPVERSION__) || defined(__ADSPBLACKFIN__) || defined(__ADSPTS__) || defined(__ADSP21000__)[m
[32m+[m[32m# define COMPILER_ID "ADSP"[m
[32m+[m[32m#if defined(__VISUALDSPVERSION__)[m
[32m+[m[32m  /* __VISUALDSPVERSION__ = 0xVVRRPP00 */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR HEX(__VISUALDSPVERSION__>>24)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR HEX(__VISUALDSPVERSION__>>16 & 0xFF)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH HEX(__VISUALDSPVERSION__>>8  & 0xFF)[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#elif defined(__IAR_SYSTEMS_ICC__) || defined(__IAR_SYSTEMS_ICC)[m
[32m+[m[32m# define COMPILER_ID "IAR"[m
[32m+[m[32m# if defined(__VER__) && defined(__ICCARM__)[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC((__VER__) / 1000000)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC(((__VER__) / 1000) % 1000)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC((__VER__) % 1000)[m
[32m+[m[32m#  define COMPILER_VERSION_INTERNAL DEC(__IAR_SYSTEMS_ICC__)[m
[32m+[m[32m# elif defined(__VER__) && (defined(__ICCAVR__) || defined(__ICCRX__) || defined(__ICCRH850__) || defined(__ICCRL78__) || defined(__ICC430__) || defined(__ICCRISCV__))[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC((__VER__) / 100)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC((__VER__) - (((__VER__) / 100)*100))[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__SUBVERSION__)[m
[32m+[m[32m#  define COMPILER_VERSION_INTERNAL DEC(__IAR_SYSTEMS_ICC__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__SDCC_VERSION_MAJOR) || defined(SDCC)[m
[32m+[m[32m# define COMPILER_ID "SDCC"[m
[32m+[m[32m# if defined(__SDCC_VERSION_MAJOR)[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC(__SDCC_VERSION_MAJOR)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC(__SDCC_VERSION_MINOR)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__SDCC_VERSION_PATCH)[m
[32m+[m[32m# else[m
[32m+[m[32m  /* SDCC = VRP */[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC(SDCC/100)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC(SDCC/10 % 10)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(SDCC    % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m
[32m+[m[32m/* These compilers are either not known or too old to define an[m
[32m+[m[32m  identification macro.  Try to identify the platform and guess that[m
[32m+[m[32m  it is the native compiler.  */[m
[32m+[m[32m#elif defined(__hpux) || defined(__hpua)[m
[32m+[m[32m# define COMPILER_ID "HP"[m
[32m+[m
[32m+[m[32m#else /* unknown compiler */[m
[32m+[m[32m# define COMPILER_ID ""[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct the string literal in pieces to prevent the source from[m
[32m+[m[32m   getting matched.  Store it in a pointer rather than an array[m
[32m+[m[32m   because some compilers will just produce instructions to fill the[m
[32m+[m[32m   array rather than assigning a pointer to a static array.  */[m
[32m+[m[32mchar const* info_compiler = "INFO" ":" "compiler[" COMPILER_ID "]";[m
[32m+[m[32m#ifdef SIMULATE_ID[m
[32m+[m[32mchar const* info_simulate = "INFO" ":" "simulate[" SIMULATE_ID "]";[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#ifdef __QNXNTO__[m
[32m+[m[32mchar const* qnxnto = "INFO" ":" "qnxnto[]";[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#if defined(__CRAYXE) || defined(__CRAYXC)[m
[32m+[m[32mchar const *info_cray = "INFO" ":" "compiler_wrapper[CrayPrgEnv]";[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#define STRINGIFY_HELPER(X) #X[m
[32m+[m[32m#define STRINGIFY(X) STRINGIFY_HELPER(X)[m
[32m+[m
[32m+[m[32m/* Identify known platforms by name.  */[m
[32m+[m[32m#if defined(__linux) || defined(__linux__) || defined(linux)[m
[32m+[m[32m# define PLATFORM_ID "Linux"[m
[32m+[m
[32m+[m[32m#elif defined(__CYGWIN__)[m
[32m+[m[32m# define PLATFORM_ID "Cygwin"[m
[32m+[m
[32m+[m[32m#elif defined(__MINGW32__)[m
[32m+[m[32m# define PLATFORM_ID "MinGW"[m
[32m+[m
[32m+[m[32m#elif defined(__APPLE__)[m
[32m+[m[32m# define PLATFORM_ID "Darwin"[m
[32m+[m
[32m+[m[32m#elif defined(_WIN32) || defined(__WIN32__) || defined(WIN32)[m
[32m+[m[32m# define PLATFORM_ID "Windows"[m
[32m+[m
[32m+[m[32m#elif defined(__FreeBSD__) || defined(__FreeBSD)[m
[32m+[m[32m# define PLATFORM_ID "FreeBSD"[m
[32m+[m
[32m+[m[32m#elif defined(__NetBSD__) || defined(__NetBSD)[m
[32m+[m[32m# define PLATFORM_ID "NetBSD"[m
[32m+[m
[32m+[m[32m#elif defined(__OpenBSD__) || defined(__OPENBSD)[m
[32m+[m[32m# define PLATFORM_ID "OpenBSD"[m
[32m+[m
[32m+[m[32m#elif defined(__sun) || defined(sun)[m
[32m+[m[32m# define PLATFORM_ID "SunOS"[m
[32m+[m
[32m+[m[32m#elif defined(_AIX) || defined(__AIX) || defined(__AIX__) || defined(__aix) || defined(__aix__)[m
[32m+[m[32m# define PLATFORM_ID "AIX"[m
[32m+[m
[32m+[m[32m#elif defined(__hpux) || defined(__hpux__)[m
[32m+[m[32m# define PLATFORM_ID "HP-UX"[m
[32m+[m
[32m+[m[32m#elif defined(__HAIKU__)[m
[32m+[m[32m# define PLATFORM_ID "Haiku"[m
[32m+[m
[32m+[m[32m#elif defined(__BeOS) || defined(__BEOS__) || defined(_BEOS)[m
[32m+[m[32m# define PLATFORM_ID "BeOS"[m
[32m+[m
[32m+[m[32m#elif defined(__QNX__) || defined(__QNXNTO__)[m
[32m+[m[32m# define PLATFORM_ID "QNX"[m
[32m+[m
[32m+[m[32m#elif defined(__tru64) || defined(_tru64) || defined(__TRU64__)[m
[32m+[m[32m# define PLATFORM_ID "Tru64"[m
[32m+[m
[32m+[m[32m#elif defined(__riscos) || defined(__riscos__)[m
[32m+[m[32m# define PLATFORM_ID "RISCos"[m
[32m+[m
[32m+[m[32m#elif defined(__sinix) || defined(__sinix__) || defined(__SINIX__)[m
[32m+[m[32m# define PLATFORM_ID "SINIX"[m
[32m+[m
[32m+[m[32m#elif defined(__UNIX_SV__)[m
[32m+[m[32m# define PLATFORM_ID "UNIX_SV"[m
[32m+[m
[32m+[m[32m#elif defined(__bsdos__)[m
[32m+[m[32m# define PLATFORM_ID "BSDOS"[m
[32m+[m
[32m+[m[32m#elif defined(_MPRAS) || defined(MPRAS)[m
[32m+[m[32m# define PLATFORM_ID "MP-RAS"[m
[32m+[m
[32m+[m[32m#elif defined(__osf) || defined(__osf__)[m
[32m+[m[32m# define PLATFORM_ID "OSF1"[m
[32m+[m
[32m+[m[32m#elif defined(_SCO_SV) || defined(SCO_SV) || defined(sco_sv)[m
[32m+[m[32m# define PLATFORM_ID "SCO_SV"[m
[32m+[m
[32m+[m[32m#elif defined(__ultrix) || defined(__ultrix__) || defined(_ULTRIX)[m
[32m+[m[32m# define PLATFORM_ID "ULTRIX"[m
[32m+[m
[32m+[m[32m#elif defined(__XENIX__) || defined(_XENIX) || defined(XENIX)[m
[32m+[m[32m# define PLATFORM_ID "Xenix"[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__)[m
[32m+[m[32m# if defined(__LINUX__)[m
[32m+[m[32m#  define PLATFORM_ID "Linux"[m
[32m+[m
[32m+[m[32m# elif defined(__DOS__)[m
[32m+[m[32m#  define PLATFORM_ID "DOS"[m
[32m+[m
[32m+[m[32m# elif defined(__OS2__)[m
[32m+[m[32m#  define PLATFORM_ID "OS2"[m
[32m+[m
[32m+[m[32m# elif defined(__WINDOWS__)[m
[32m+[m[32m#  define PLATFORM_ID "Windows3x"[m
[32m+[m
[32m+[m[32m# else /* unknown platform */[m
[32m+[m[32m#  define PLATFORM_ID[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__INTEGRITY)[m
[32m+[m[32m# if defined(INT_178B)[m
[32m+[m[32m#  define PLATFORM_ID "Integrity178"[m
[32m+[m
[32m+[m[32m# else /* regular Integrity */[m
[32m+[m[32m#  define PLATFORM_ID "Integrity"[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#else /* unknown platform */[m
[32m+[m[32m# define PLATFORM_ID[m
[32m+[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* For windows compilers MSVC and Intel we can determine[m
[32m+[m[32m   the architecture of the compiler being used.  This is because[m
[32m+[m[32m   the compilers do not have flags that can change the architecture,[m
[32m+[m[32m   but rather depend on which compiler is being used[m
[32m+[m[32m*/[m
[32m+[m[32m#if defined(_WIN32) && defined(_MSC_VER)[m
[32m+[m[32m# if defined(_M_IA64)[m
[32m+[m[32m#  define ARCHITECTURE_ID "IA64"[m
[32m+[m
[32m+[m[32m# elif defined(_M_X64) || defined(_M_AMD64)[m
[32m+[m[32m#  define ARCHITECTURE_ID "x64"[m
[32m+[m
[32m+[m[32m# elif defined(_M_IX86)[m
[32m+[m[32m#  define ARCHITECTURE_ID "X86"[m
[32m+[m
[32m+[m[32m# elif defined(_M_ARM64)[m
[32m+[m[32m#  define ARCHITECTURE_ID "ARM64"[m
[32m+[m
[32m+[m[32m# elif defined(_M_ARM)[m
[32m+[m[32m#  if _M_ARM == 4[m
[32m+[m[32m#   define ARCHITECTURE_ID "ARMV4I"[m
[32m+[m[32m#  elif _M_ARM == 5[m
[32m+[m[32m#   define ARCHITECTURE_ID "ARMV5I"[m
[32m+[m[32m#  else[m
[32m+[m[32m#   define ARCHITECTURE_ID "ARMV" STRINGIFY(_M_ARM)[m
[32m+[m[32m#  endif[m
[32m+[m
[32m+[m[32m# elif defined(_M_MIPS)[m
[32m+[m[32m#  define ARCHITECTURE_ID "MIPS"[m
[32m+[m
[32m+[m[32m# elif defined(_M_SH)[m
[32m+[m[32m#  define ARCHITECTURE_ID "SHx"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__)[m
[32m+[m[32m# if defined(_M_I86)[m
[32m+[m[32m#  define ARCHITECTURE_ID "I86"[m
[32m+[m
[32m+[m[32m# elif defined(_M_IX86)[m
[32m+[m[32m#  define ARCHITECTURE_ID "X86"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__IAR_SYSTEMS_ICC__) || defined(__IAR_SYSTEMS_ICC)[m
[32m+[m[32m# if defined(__ICCARM__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "ARM"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRX__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RX"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRH850__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RH850"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRL78__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RL78"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRISCV__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RISCV"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCAVR__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "AVR"[m
[32m+[m
[32m+[m[32m# elif defined(__ICC430__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "MSP430"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__ghs__)[m
[32m+[m[32m# if defined(__PPC64__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "PPC64"[m
[32m+[m
[32m+[m[32m# elif defined(__ppc__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "PPC"[m
[32m+[m
[32m+[m[32m# elif defined(__ARM__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "ARM"[m
[32m+[m
[32m+[m[32m# elif defined(__x86_64__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "x64"[m
[32m+[m
[32m+[m[32m# elif defined(__i386__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "X86"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m[32m#else[m
[32m+[m[32m#  define ARCHITECTURE_ID[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Convert integer to decimal digit literals.  */[m
[32m+[m[32m#define DEC(n)                   \[m
[32m+[m[32m  ('0' + (((n) / 10000000)%10)), \[m
[32m+[m[32m  ('0' + (((n) / 1000000)%10)),  \[m
[32m+[m[32m  ('0' + (((n) / 100000)%10)),   \[m
[32m+[m[32m  ('0' + (((n) / 10000)%10)),    \[m
[32m+[m[32m  ('0' + (((n) / 1000)%10)),     \[m
[32m+[m[32m  ('0' + (((n) / 100)%10)),      \[m
[32m+[m[32m  ('0' + (((n) / 10)%10)),       \[m
[32m+[m[32m  ('0' +  ((n) % 10))[m
[32m+[m
[32m+[m[32m/* Convert integer to hex digit literals.  */[m
[32m+[m[32m#define HEX(n)             \[m
[32m+[m[32m  ('0' + ((n)>>28 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>24 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>20 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>16 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>12 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>8  & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>4  & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)     & 0xF))[m
[32m+[m
[32m+[m[32m/* Construct a string literal encoding the version number components. */[m
[32m+[m[32m#ifdef COMPILER_VERSION_MAJOR[m
[32m+[m[32mchar const info_version[] = {[m
[32m+[m[32m  'I', 'N', 'F', 'O', ':',[m
[32m+[m[32m  'c','o','m','p','i','l','e','r','_','v','e','r','s','i','o','n','[',[m
[32m+[m[32m  COMPILER_VERSION_MAJOR,[m
[32m+[m[32m# ifdef COMPILER_VERSION_MINOR[m
[32m+[m[32m  '.', COMPILER_VERSION_MINOR,[m
[32m+[m[32m#  ifdef COMPILER_VERSION_PATCH[m
[32m+[m[32m   '.', COMPILER_VERSION_PATCH,[m
[32m+[m[32m#   ifdef COMPILER_VERSION_TWEAK[m
[32m+[m[32m    '.', COMPILER_VERSION_TWEAK,[m
[32m+[m[32m#   endif[m
[32m+[m[32m#  endif[m
[32m+[m[32m# endif[m
[32m+[m[32m  ']','\0'};[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct a string literal encoding the internal version number. */[m
[32m+[m[32m#ifdef COMPILER_VERSION_INTERNAL[m
[32m+[m[32mchar const info_version_internal[] = {[m
[32m+[m[32m  'I', 'N', 'F', 'O', ':',[m
[32m+[m[32m  'c','o','m','p','i','l','e','r','_','v','e','r','s','i','o','n','_',[m
[32m+[m[32m  'i','n','t','e','r','n','a','l','[',[m
[32m+[m[32m  COMPILER_VERSION_INTERNAL,']','\0'};[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct a string literal encoding the version number components. */[m
[32m+[m[32m#ifdef SIMULATE_VERSION_MAJOR[m
[32m+[m[32mchar const info_simulate_version[] = {[m
[32m+[m[32m  'I', 'N', 'F', 'O', ':',[m
[32m+[m[32m  's','i','m','u','l','a','t','e','_','v','e','r','s','i','o','n','[',[m
[32m+[m[32m  SIMULATE_VERSION_MAJOR,[m
[32m+[m[32m# ifdef SIMULATE_VERSION_MINOR[m
[32m+[m[32m  '.', SIMULATE_VERSION_MINOR,[m
[32m+[m[32m#  ifdef SIMULATE_VERSION_PATCH[m
[32m+[m[32m   '.', SIMULATE_VERSION_PATCH,[m
[32m+[m[32m#   ifdef SIMULATE_VERSION_TWEAK[m
[32m+[m[32m    '.', SIMULATE_VERSION_TWEAK,[m
[32m+[m[32m#   endif[m
[32m+[m[32m#  endif[m
[32m+[m[32m# endif[m
[32m+[m[32m  ']','\0'};[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct the string literal in pieces to prevent the source from[m
[32m+[m[32m   getting matched.  Store it in a pointer rather than an array[m
[32m+[m[32m   because some compilers will just produce instructions to fill the[m
[32m+[m[32m   array rather than assigning a pointer to a static array.  */[m
[32m+[m[32mchar const* info_platform = "INFO" ":" "platform[" PLATFORM_ID "]";[m
[32m+[m[32mchar const* info_arch = "INFO" ":" "arch[" ARCHITECTURE_ID "]";[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32m#if !defined(__STDC__)[m
[32m+[m[32m# if (defined(_MSC_VER) && !defined(__clang__)) \[m
[32m+[m[32m  || (defined(__ibmxl__) || defined(__IBMC__))[m
[32m+[m[32m#  define C_DIALECT "90"[m
[32m+[m[32m# else[m
[32m+[m[32m#  define C_DIALECT[m
[32m+[m[32m# endif[m
[32m+[m[32m#elif __STDC_VERSION__ >= 201000L[m
[32m+[m[32m# define C_DIALECT "11"[m
[32m+[m[32m#elif __STDC_VERSION__ >= 199901L[m
[32m+[m[32m# define C_DIALECT "99"[m
[32m+[m[32m#else[m
[32m+[m[32m# define C_DIALECT "90"[m
[32m+[m[32m#endif[m
[32m+[m[32mconst char* info_language_dialect_default =[m
[32m+[m[32m  "INFO" ":" "dialect_default[" C_DIALECT "]";[m
[32m+[m
[32m+[m[32m/*--------------------------------------------------------------------------*/[m
[32m+[m
[32m+[m[32m#ifdef ID_VOID_MAIN[m
[32m+[m[32mvoid main() {}[m
[32m+[m[32m#else[m
[32m+[m[32m# if defined(__CLASSIC_C__)[m
[32m+[m[32mint main(argc, argv) int argc; char *argv[];[m
[32m+[m[32m# else[m
[32m+[m[32mint main(int argc, char* argv[])[m
[32m+[m[32m# endif[m
[32m+[m[32m{[m
[32m+[m[32m  int require = 0;[m
[32m+[m[32m  require += info_compiler[argc];[m
[32m+[m[32m  require += info_platform[argc];[m
[32m+[m[32m  require += info_arch[argc];[m
[32m+[m[32m#ifdef COMPILER_VERSION_MAJOR[m
[32m+[m[32m  require += info_version[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#ifdef COMPILER_VERSION_INTERNAL[m
[32m+[m[32m  require += info_version_internal[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#ifdef SIMULATE_ID[m
[32m+[m[32m  require += info_simulate[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#ifdef SIMULATE_VERSION_MAJOR[m
[32m+[m[32m  require += info_simulate_version[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#if defined(__CRAYXE) || defined(__CRAYXC)[m
[32m+[m[32m  require += info_cray[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m  require += info_language_dialect_default[argc];[m
[32m+[m[32m  (void)argv;[m
[32m+[m[32m  return require;[m
[32m+[m[32m}[m
[32m+[m[32m#endif[m
[1mdiff --git a/kernel/mm/CMakeFiles/3.15.5/CompilerIdCXX/CMakeCXXCompilerId.cpp b/kernel/mm/CMakeFiles/3.15.5/CompilerIdCXX/CMakeCXXCompilerId.cpp[m
[1mnew file mode 100644[m
[1mindex 0000000..4761ea2[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/3.15.5/CompilerIdCXX/CMakeCXXCompilerId.cpp[m
[36m@@ -0,0 +1,644 @@[m
[32m+[m[32m/* This source file must have a .cpp extension so that all C++ compilers[m
[32m+[m[32m   recognize the extension without flags.  Borland does not know .cxx for[m
[32m+[m[32m   example.  */[m
[32m+[m[32m#ifndef __cplusplus[m
[32m+[m[32m# error "A C compiler has been selected for C++."[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m
[32m+[m[32m/* Version number components: V=Version, R=Revision, P=Patch[m
[32m+[m[32m   Version date components:   YYYY=Year, MM=Month,   DD=Day  */[m
[32m+[m
[32m+[m[32m#if defined(__COMO__)[m
[32m+[m[32m# define COMPILER_ID "Comeau"[m
[32m+[m[32m  /* __COMO_VERSION__ = VRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__COMO_VERSION__ / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__COMO_VERSION__ % 100)[m
[32m+[m
[32m+[m[32m#elif defined(__INTEL_COMPILER) || defined(__ICC)[m
[32m+[m[32m# define COMPILER_ID "Intel"[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m#  define SIMULATE_ID "MSVC"[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC__)[m
[32m+[m[32m#  define SIMULATE_ID "GNU"[m
[32m+[m[32m# endif[m
[32m+[m[32m  /* __INTEL_COMPILER = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__INTEL_COMPILER/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__INTEL_COMPILER/10 % 10)[m
[32m+[m[32m# if defined(__INTEL_COMPILER_UPDATE)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__INTEL_COMPILER_UPDATE)[m
[32m+[m[32m# else[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__INTEL_COMPILER   % 10)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__INTEL_COMPILER_BUILD_DATE)[m
[32m+[m[32m  /* __INTEL_COMPILER_BUILD_DATE = YYYYMMDD */[m
[32m+[m[32m#  define COMPILER_VERSION_TWEAK DEC(__INTEL_COMPILER_BUILD_DATE)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m   /* _MSC_VER = VVRR */[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC__)[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(__GNUC__)[m
[32m+[m[32m# elif defined(__GNUG__)[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(__GNUG__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_MINOR__)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(__GNUC_MINOR__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m#  define SIMULATE_VERSION_PATCH DEC(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__PATHCC__)[m
[32m+[m[32m# define COMPILER_ID "PathScale"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__PATHCC__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__PATHCC_MINOR__)[m
[32m+[m[32m# if defined(__PATHCC_PATCHLEVEL__)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__PATHCC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__BORLANDC__) && defined(__CODEGEARC_VERSION__)[m
[32m+[m[32m# define COMPILER_ID "Embarcadero"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR HEX(__CODEGEARC_VERSION__>>24 & 0x00FF)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR HEX(__CODEGEARC_VERSION__>>16 & 0x00FF)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__CODEGEARC_VERSION__     & 0xFFFF)[m
[32m+[m
[32m+[m[32m#elif defined(__BORLANDC__)[m
[32m+[m[32m# define COMPILER_ID "Borland"[m
[32m+[m[32m  /* __BORLANDC__ = 0xVRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR HEX(__BORLANDC__>>8)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR HEX(__BORLANDC__ & 0xFF)[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__) && __WATCOMC__ < 1200[m
[32m+[m[32m# define COMPILER_ID "Watcom"[m
[32m+[m[32m   /* __WATCOMC__ = VVRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__WATCOMC__ / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC((__WATCOMC__ / 10) % 10)[m
[32m+[m[32m# if (__WATCOMC__ % 10) > 0[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__WATCOMC__ % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__)[m
[32m+[m[32m# define COMPILER_ID "OpenWatcom"[m
[32m+[m[32m   /* __WATCOMC__ = VVRP + 1100 */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC((__WATCOMC__ - 1100) / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC((__WATCOMC__ / 10) % 10)[m
[32m+[m[32m# if (__WATCOMC__ % 10) > 0[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__WATCOMC__ % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__SUNPRO_CC)[m
[32m+[m[32m# define COMPILER_ID "SunPro"[m
[32m+[m[32m# if __SUNPRO_CC >= 0x5100[m
[32m+[m[32m   /* __SUNPRO_CC = 0xVRRP */[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR HEX(__SUNPRO_CC>>12)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR HEX(__SUNPRO_CC>>4 & 0xFF)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH HEX(__SUNPRO_CC    & 0xF)[m
[32m+[m[32m# else[m
[32m+[m[32m   /* __SUNPRO_CC = 0xVRP */[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR HEX(__SUNPRO_CC>>8)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR HEX(__SUNPRO_CC>>4 & 0xF)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH HEX(__SUNPRO_CC    & 0xF)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__HP_aCC)[m
[32m+[m[32m# define COMPILER_ID "HP"[m
[32m+[m[32m  /* __HP_aCC = VVRRPP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__HP_aCC/10000)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__HP_aCC/100 % 100)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__HP_aCC     % 100)[m
[32m+[m
[32m+[m[32m#elif defined(__DECCXX)[m
[32m+[m[32m# define COMPILER_ID "Compaq"[m
[32m+[m[32m  /* __DECCXX_VER = VVRRTPPPP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__DECCXX_VER/10000000)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__DECCXX_VER/100000  % 100)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__DECCXX_VER         % 10000)[m
[32m+[m
[32m+[m[32m#elif defined(__IBMCPP__) && defined(__COMPILER_VER__)[m
[32m+[m[32m# define COMPILER_ID "zOS"[m
[32m+[m[32m  /* __IBMCPP__ = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__IBMCPP__/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__IBMCPP__/10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__IBMCPP__    % 10)[m
[32m+[m
[32m+[m[32m#elif defined(__ibmxl__) && defined(__clang__)[m
[32m+[m[32m# define COMPILER_ID "XLClang"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__ibmxl_version__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__ibmxl_release__)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__ibmxl_modification__)[m
[32m+[m[32m# define COMPILER_VERSION_TWEAK DEC(__ibmxl_ptf_fix_level__)[m
[32m+[m
[32m+[m
[32m+[m[32m#elif defined(__IBMCPP__) && !defined(__COMPILER_VER__) && __IBMCPP__ >= 800[m
[32m+[m[32m# define COMPILER_ID "XL"[m
[32m+[m[32m  /* __IBMCPP__ = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__IBMCPP__/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__IBMCPP__/10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__IBMCPP__    % 10)[m
[32m+[m
[32m+[m[32m#elif defined(__IBMCPP__) && !defined(__COMPILER_VER__) && __IBMCPP__ < 800[m
[32m+[m[32m# define COMPILER_ID "VisualAge"[m
[32m+[m[32m  /* __IBMCPP__ = VRP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__IBMCPP__/100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__IBMCPP__/10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__IBMCPP__    % 10)[m
[32m+[m
[32m+[m[32m#elif defined(__PGI)[m
[32m+[m[32m# define COMPILER_ID "PGI"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__PGIC__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__PGIC_MINOR__)[m
[32m+[m[32m# if defined(__PGIC_PATCHLEVEL__)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__PGIC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(_CRAYC)[m
[32m+[m[32m# define COMPILER_ID "Cray"[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(_RELEASE_MAJOR)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(_RELEASE_MINOR)[m
[32m+[m
[32m+[m[32m#elif defined(__TI_COMPILER_VERSION__)[m
[32m+[m[32m# define COMPILER_ID "TI"[m
[32m+[m[32m  /* __TI_COMPILER_VERSION__ = VVVRRRPPP */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__TI_COMPILER_VERSION__/1000000)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__TI_COMPILER_VERSION__/1000   % 1000)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__TI_COMPILER_VERSION__        % 1000)[m
[32m+[m
[32m+[m[32m#elif defined(__FUJITSU) || defined(__FCC_VERSION) || defined(__fcc_version)[m
[32m+[m[32m# define COMPILER_ID "Fujitsu"[m
[32m+[m
[32m+[m[32m#elif defined(__ghs__)[m
[32m+[m[32m# define COMPILER_ID "GHS"[m
[32m+[m[32m/* __GHS_VERSION_NUMBER = VVVVRP */[m
[32m+[m[32m# ifdef __GHS_VERSION_NUMBER[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__GHS_VERSION_NUMBER / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__GHS_VERSION_NUMBER / 10 % 10)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__GHS_VERSION_NUMBER      % 10)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__SCO_VERSION__)[m
[32m+[m[32m# define COMPILER_ID "SCO"[m
[32m+[m
[32m+[m[32m#elif defined(__ARMCC_VERSION) && !defined(__clang__)[m
[32m+[m[32m# define COMPILER_ID "ARMCC"[m
[32m+[m[32m#if __ARMCC_VERSION >= 1000000[m
[32m+[m[32m  /* __ARMCC_VERSION = VRRPPPP */[m
[32m+[m[32m  # define COMPILER_VERSION_MAJOR DEC(__ARMCC_VERSION/1000000)[m
[32m+[m[32m  # define COMPILER_VERSION_MINOR DEC(__ARMCC_VERSION/10000 % 100)[m
[32m+[m[32m  # define COMPILER_VERSION_PATCH DEC(__ARMCC_VERSION     % 10000)[m
[32m+[m[32m#else[m
[32m+[m[32m  /* __ARMCC_VERSION = VRPPPP */[m
[32m+[m[32m  # define COMPILER_VERSION_MAJOR DEC(__ARMCC_VERSION/100000)[m
[32m+[m[32m  # define COMPILER_VERSION_MINOR DEC(__ARMCC_VERSION/10000 % 10)[m
[32m+[m[32m  # define COMPILER_VERSION_PATCH DEC(__ARMCC_VERSION    % 10000)[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m
[32m+[m[32m#elif defined(__clang__) && defined(__apple_build_version__)[m
[32m+[m[32m# define COMPILER_ID "AppleClang"[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m#  define SIMULATE_ID "MSVC"[m
[32m+[m[32m# endif[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__clang_major__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__clang_minor__)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__clang_patchlevel__)[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m   /* _MSC_VER = VVRR */[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# endif[m
[32m+[m[32m# define COMPILER_VERSION_TWEAK DEC(__apple_build_version__)[m
[32m+[m
[32m+[m[32m#elif defined(__clang__) && defined(__ARMCOMPILER_VERSION)[m
[32m+[m[32m# define COMPILER_ID "ARMClang"[m
[32m+[m[32m  # define COMPILER_VERSION_MAJOR DEC(__ARMCOMPILER_VERSION/1000000)[m
[32m+[m[32m  # define COMPILER_VERSION_MINOR DEC(__ARMCOMPILER_VERSION/10000 % 100)[m
[32m+[m[32m  # define COMPILER_VERSION_PATCH DEC(__ARMCOMPILER_VERSION     % 10000)[m
[32m+[m[32m# define COMPILER_VERSION_INTERNAL DEC(__ARMCOMPILER_VERSION)[m
[32m+[m
[32m+[m[32m#elif defined(__clang__)[m
[32m+[m[32m# define COMPILER_ID "Clang"[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m#  define SIMULATE_ID "MSVC"[m
[32m+[m[32m# endif[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(__clang_major__)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(__clang_minor__)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH DEC(__clang_patchlevel__)[m
[32m+[m[32m# if defined(_MSC_VER)[m
[32m+[m[32m   /* _MSC_VER = VVRR */[m
[32m+[m[32m#  define SIMULATE_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m#  define SIMULATE_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__GNUC__) || defined(__GNUG__)[m
[32m+[m[32m# define COMPILER_ID "GNU"[m
[32m+[m[32m# if defined(__GNUC__)[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC(__GNUC__)[m
[32m+[m[32m# else[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC(__GNUG__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_MINOR__)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC(__GNUC_MINOR__)[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__GNUC_PATCHLEVEL__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(_MSC_VER)[m
[32m+[m[32m# define COMPILER_ID "MSVC"[m
[32m+[m[32m  /* _MSC_VER = VVRR */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR DEC(_MSC_VER / 100)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR DEC(_MSC_VER % 100)[m
[32m+[m[32m# if defined(_MSC_FULL_VER)[m
[32m+[m[32m#  if _MSC_VER >= 1400[m
[32m+[m[32m    /* _MSC_FULL_VER = VVRRPPPPP */[m
[32m+[m[32m#   define COMPILER_VERSION_PATCH DEC(_MSC_FULL_VER % 100000)[m
[32m+[m[32m#  else[m
[32m+[m[32m    /* _MSC_FULL_VER = VVRRPPPP */[m
[32m+[m[32m#   define COMPILER_VERSION_PATCH DEC(_MSC_FULL_VER % 10000)[m
[32m+[m[32m#  endif[m
[32m+[m[32m# endif[m
[32m+[m[32m# if defined(_MSC_BUILD)[m
[32m+[m[32m#  define COMPILER_VERSION_TWEAK DEC(_MSC_BUILD)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__VISUALDSPVERSION__) || defined(__ADSPBLACKFIN__) || defined(__ADSPTS__) || defined(__ADSP21000__)[m
[32m+[m[32m# define COMPILER_ID "ADSP"[m
[32m+[m[32m#if defined(__VISUALDSPVERSION__)[m
[32m+[m[32m  /* __VISUALDSPVERSION__ = 0xVVRRPP00 */[m
[32m+[m[32m# define COMPILER_VERSION_MAJOR HEX(__VISUALDSPVERSION__>>24)[m
[32m+[m[32m# define COMPILER_VERSION_MINOR HEX(__VISUALDSPVERSION__>>16 & 0xFF)[m
[32m+[m[32m# define COMPILER_VERSION_PATCH HEX(__VISUALDSPVERSION__>>8  & 0xFF)[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#elif defined(__IAR_SYSTEMS_ICC__) || defined(__IAR_SYSTEMS_ICC)[m
[32m+[m[32m# define COMPILER_ID "IAR"[m
[32m+[m[32m# if defined(__VER__) && defined(__ICCARM__)[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC((__VER__) / 1000000)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC(((__VER__) / 1000) % 1000)[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC((__VER__) % 1000)[m
[32m+[m[32m#  define COMPILER_VERSION_INTERNAL DEC(__IAR_SYSTEMS_ICC__)[m
[32m+[m[32m# elif defined(__VER__) && (defined(__ICCAVR__) || defined(__ICCRX__) || defined(__ICCRH850__) || defined(__ICCRL78__) || defined(__ICC430__) || defined(__ICCRISCV__))[m
[32m+[m[32m#  define COMPILER_VERSION_MAJOR DEC((__VER__) / 100)[m
[32m+[m[32m#  define COMPILER_VERSION_MINOR DEC((__VER__) - (((__VER__) / 100)*100))[m
[32m+[m[32m#  define COMPILER_VERSION_PATCH DEC(__SUBVERSION__)[m
[32m+[m[32m#  define COMPILER_VERSION_INTERNAL DEC(__IAR_SYSTEMS_ICC__)[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m
[32m+[m[32m/* These compilers are either not known or too old to define an[m
[32m+[m[32m  identification macro.  Try to identify the platform and guess that[m
[32m+[m[32m  it is the native compiler.  */[m
[32m+[m[32m#elif defined(__hpux) || defined(__hpua)[m
[32m+[m[32m# define COMPILER_ID "HP"[m
[32m+[m
[32m+[m[32m#else /* unknown compiler */[m
[32m+[m[32m# define COMPILER_ID ""[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct the string literal in pieces to prevent the source from[m
[32m+[m[32m   getting matched.  Store it in a pointer rather than an array[m
[32m+[m[32m   because some compilers will just produce instructions to fill the[m
[32m+[m[32m   array rather than assigning a pointer to a static array.  */[m
[32m+[m[32mchar const* info_compiler = "INFO" ":" "compiler[" COMPILER_ID "]";[m
[32m+[m[32m#ifdef SIMULATE_ID[m
[32m+[m[32mchar const* info_simulate = "INFO" ":" "simulate[" SIMULATE_ID "]";[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#ifdef __QNXNTO__[m
[32m+[m[32mchar const* qnxnto = "INFO" ":" "qnxnto[]";[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#if defined(__CRAYXE) || defined(__CRAYXC)[m
[32m+[m[32mchar const *info_cray = "INFO" ":" "compiler_wrapper[CrayPrgEnv]";[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m#define STRINGIFY_HELPER(X) #X[m
[32m+[m[32m#define STRINGIFY(X) STRINGIFY_HELPER(X)[m
[32m+[m
[32m+[m[32m/* Identify known platforms by name.  */[m
[32m+[m[32m#if defined(__linux) || defined(__linux__) || defined(linux)[m
[32m+[m[32m# define PLATFORM_ID "Linux"[m
[32m+[m
[32m+[m[32m#elif defined(__CYGWIN__)[m
[32m+[m[32m# define PLATFORM_ID "Cygwin"[m
[32m+[m
[32m+[m[32m#elif defined(__MINGW32__)[m
[32m+[m[32m# define PLATFORM_ID "MinGW"[m
[32m+[m
[32m+[m[32m#elif defined(__APPLE__)[m
[32m+[m[32m# define PLATFORM_ID "Darwin"[m
[32m+[m
[32m+[m[32m#elif defined(_WIN32) || defined(__WIN32__) || defined(WIN32)[m
[32m+[m[32m# define PLATFORM_ID "Windows"[m
[32m+[m
[32m+[m[32m#elif defined(__FreeBSD__) || defined(__FreeBSD)[m
[32m+[m[32m# define PLATFORM_ID "FreeBSD"[m
[32m+[m
[32m+[m[32m#elif defined(__NetBSD__) || defined(__NetBSD)[m
[32m+[m[32m# define PLATFORM_ID "NetBSD"[m
[32m+[m
[32m+[m[32m#elif defined(__OpenBSD__) || defined(__OPENBSD)[m
[32m+[m[32m# define PLATFORM_ID "OpenBSD"[m
[32m+[m
[32m+[m[32m#elif defined(__sun) || defined(sun)[m
[32m+[m[32m# define PLATFORM_ID "SunOS"[m
[32m+[m
[32m+[m[32m#elif defined(_AIX) || defined(__AIX) || defined(__AIX__) || defined(__aix) || defined(__aix__)[m
[32m+[m[32m# define PLATFORM_ID "AIX"[m
[32m+[m
[32m+[m[32m#elif defined(__hpux) || defined(__hpux__)[m
[32m+[m[32m# define PLATFORM_ID "HP-UX"[m
[32m+[m
[32m+[m[32m#elif defined(__HAIKU__)[m
[32m+[m[32m# define PLATFORM_ID "Haiku"[m
[32m+[m
[32m+[m[32m#elif defined(__BeOS) || defined(__BEOS__) || defined(_BEOS)[m
[32m+[m[32m# define PLATFORM_ID "BeOS"[m
[32m+[m
[32m+[m[32m#elif defined(__QNX__) || defined(__QNXNTO__)[m
[32m+[m[32m# define PLATFORM_ID "QNX"[m
[32m+[m
[32m+[m[32m#elif defined(__tru64) || defined(_tru64) || defined(__TRU64__)[m
[32m+[m[32m# define PLATFORM_ID "Tru64"[m
[32m+[m
[32m+[m[32m#elif defined(__riscos) || defined(__riscos__)[m
[32m+[m[32m# define PLATFORM_ID "RISCos"[m
[32m+[m
[32m+[m[32m#elif defined(__sinix) || defined(__sinix__) || defined(__SINIX__)[m
[32m+[m[32m# define PLATFORM_ID "SINIX"[m
[32m+[m
[32m+[m[32m#elif defined(__UNIX_SV__)[m
[32m+[m[32m# define PLATFORM_ID "UNIX_SV"[m
[32m+[m
[32m+[m[32m#elif defined(__bsdos__)[m
[32m+[m[32m# define PLATFORM_ID "BSDOS"[m
[32m+[m
[32m+[m[32m#elif defined(_MPRAS) || defined(MPRAS)[m
[32m+[m[32m# define PLATFORM_ID "MP-RAS"[m
[32m+[m
[32m+[m[32m#elif defined(__osf) || defined(__osf__)[m
[32m+[m[32m# define PLATFORM_ID "OSF1"[m
[32m+[m
[32m+[m[32m#elif defined(_SCO_SV) || defined(SCO_SV) || defined(sco_sv)[m
[32m+[m[32m# define PLATFORM_ID "SCO_SV"[m
[32m+[m
[32m+[m[32m#elif defined(__ultrix) || defined(__ultrix__) || defined(_ULTRIX)[m
[32m+[m[32m# define PLATFORM_ID "ULTRIX"[m
[32m+[m
[32m+[m[32m#elif defined(__XENIX__) || defined(_XENIX) || defined(XENIX)[m
[32m+[m[32m# define PLATFORM_ID "Xenix"[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__)[m
[32m+[m[32m# if defined(__LINUX__)[m
[32m+[m[32m#  define PLATFORM_ID "Linux"[m
[32m+[m
[32m+[m[32m# elif defined(__DOS__)[m
[32m+[m[32m#  define PLATFORM_ID "DOS"[m
[32m+[m
[32m+[m[32m# elif defined(__OS2__)[m
[32m+[m[32m#  define PLATFORM_ID "OS2"[m
[32m+[m
[32m+[m[32m# elif defined(__WINDOWS__)[m
[32m+[m[32m#  define PLATFORM_ID "Windows3x"[m
[32m+[m
[32m+[m[32m# else /* unknown platform */[m
[32m+[m[32m#  define PLATFORM_ID[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__INTEGRITY)[m
[32m+[m[32m# if defined(INT_178B)[m
[32m+[m[32m#  define PLATFORM_ID "Integrity178"[m
[32m+[m
[32m+[m[32m# else /* regular Integrity */[m
[32m+[m[32m#  define PLATFORM_ID "Integrity"[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#else /* unknown platform */[m
[32m+[m[32m# define PLATFORM_ID[m
[32m+[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* For windows compilers MSVC and Intel we can determine[m
[32m+[m[32m   the architecture of the compiler being used.  This is because[m
[32m+[m[32m   the compilers do not have flags that can change the architecture,[m
[32m+[m[32m   but rather depend on which compiler is being used[m
[32m+[m[32m*/[m
[32m+[m[32m#if defined(_WIN32) && defined(_MSC_VER)[m
[32m+[m[32m# if defined(_M_IA64)[m
[32m+[m[32m#  define ARCHITECTURE_ID "IA64"[m
[32m+[m
[32m+[m[32m# elif defined(_M_X64) || defined(_M_AMD64)[m
[32m+[m[32m#  define ARCHITECTURE_ID "x64"[m
[32m+[m
[32m+[m[32m# elif defined(_M_IX86)[m
[32m+[m[32m#  define ARCHITECTURE_ID "X86"[m
[32m+[m
[32m+[m[32m# elif defined(_M_ARM64)[m
[32m+[m[32m#  define ARCHITECTURE_ID "ARM64"[m
[32m+[m
[32m+[m[32m# elif defined(_M_ARM)[m
[32m+[m[32m#  if _M_ARM == 4[m
[32m+[m[32m#   define ARCHITECTURE_ID "ARMV4I"[m
[32m+[m[32m#  elif _M_ARM == 5[m
[32m+[m[32m#   define ARCHITECTURE_ID "ARMV5I"[m
[32m+[m[32m#  else[m
[32m+[m[32m#   define ARCHITECTURE_ID "ARMV" STRINGIFY(_M_ARM)[m
[32m+[m[32m#  endif[m
[32m+[m
[32m+[m[32m# elif defined(_M_MIPS)[m
[32m+[m[32m#  define ARCHITECTURE_ID "MIPS"[m
[32m+[m
[32m+[m[32m# elif defined(_M_SH)[m
[32m+[m[32m#  define ARCHITECTURE_ID "SHx"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__WATCOMC__)[m
[32m+[m[32m# if defined(_M_I86)[m
[32m+[m[32m#  define ARCHITECTURE_ID "I86"[m
[32m+[m
[32m+[m[32m# elif defined(_M_IX86)[m
[32m+[m[32m#  define ARCHITECTURE_ID "X86"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__IAR_SYSTEMS_ICC__) || defined(__IAR_SYSTEMS_ICC)[m
[32m+[m[32m# if defined(__ICCARM__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "ARM"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRX__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RX"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRH850__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RH850"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRL78__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RL78"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCRISCV__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "RISCV"[m
[32m+[m
[32m+[m[32m# elif defined(__ICCAVR__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "AVR"[m
[32m+[m
[32m+[m[32m# elif defined(__ICC430__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "MSP430"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m
[32m+[m[32m#elif defined(__ghs__)[m
[32m+[m[32m# if defined(__PPC64__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "PPC64"[m
[32m+[m
[32m+[m[32m# elif defined(__ppc__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "PPC"[m
[32m+[m
[32m+[m[32m# elif defined(__ARM__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "ARM"[m
[32m+[m
[32m+[m[32m# elif defined(__x86_64__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "x64"[m
[32m+[m
[32m+[m[32m# elif defined(__i386__)[m
[32m+[m[32m#  define ARCHITECTURE_ID "X86"[m
[32m+[m
[32m+[m[32m# else /* unknown architecture */[m
[32m+[m[32m#  define ARCHITECTURE_ID ""[m
[32m+[m[32m# endif[m
[32m+[m[32m#else[m
[32m+[m[32m#  define ARCHITECTURE_ID[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Convert integer to decimal digit literals.  */[m
[32m+[m[32m#define DEC(n)                   \[m
[32m+[m[32m  ('0' + (((n) / 10000000)%10)), \[m
[32m+[m[32m  ('0' + (((n) / 1000000)%10)),  \[m
[32m+[m[32m  ('0' + (((n) / 100000)%10)),   \[m
[32m+[m[32m  ('0' + (((n) / 10000)%10)),    \[m
[32m+[m[32m  ('0' + (((n) / 1000)%10)),     \[m
[32m+[m[32m  ('0' + (((n) / 100)%10)),      \[m
[32m+[m[32m  ('0' + (((n) / 10)%10)),       \[m
[32m+[m[32m  ('0' +  ((n) % 10))[m
[32m+[m
[32m+[m[32m/* Convert integer to hex digit literals.  */[m
[32m+[m[32m#define HEX(n)             \[m
[32m+[m[32m  ('0' + ((n)>>28 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>24 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>20 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>16 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>12 & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>8  & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)>>4  & 0xF)), \[m
[32m+[m[32m  ('0' + ((n)     & 0xF))[m
[32m+[m
[32m+[m[32m/* Construct a string literal encoding the version number components. */[m
[32m+[m[32m#ifdef COMPILER_VERSION_MAJOR[m
[32m+[m[32mchar const info_version[] = {[m
[32m+[m[32m  'I', 'N', 'F', 'O', ':',[m
[32m+[m[32m  'c','o','m','p','i','l','e','r','_','v','e','r','s','i','o','n','[',[m
[32m+[m[32m  COMPILER_VERSION_MAJOR,[m
[32m+[m[32m# ifdef COMPILER_VERSION_MINOR[m
[32m+[m[32m  '.', COMPILER_VERSION_MINOR,[m
[32m+[m[32m#  ifdef COMPILER_VERSION_PATCH[m
[32m+[m[32m   '.', COMPILER_VERSION_PATCH,[m
[32m+[m[32m#   ifdef COMPILER_VERSION_TWEAK[m
[32m+[m[32m    '.', COMPILER_VERSION_TWEAK,[m
[32m+[m[32m#   endif[m
[32m+[m[32m#  endif[m
[32m+[m[32m# endif[m
[32m+[m[32m  ']','\0'};[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct a string literal encoding the internal version number. */[m
[32m+[m[32m#ifdef COMPILER_VERSION_INTERNAL[m
[32m+[m[32mchar const info_version_internal[] = {[m
[32m+[m[32m  'I', 'N', 'F', 'O', ':',[m
[32m+[m[32m  'c','o','m','p','i','l','e','r','_','v','e','r','s','i','o','n','_',[m
[32m+[m[32m  'i','n','t','e','r','n','a','l','[',[m
[32m+[m[32m  COMPILER_VERSION_INTERNAL,']','\0'};[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct a string literal encoding the version number components. */[m
[32m+[m[32m#ifdef SIMULATE_VERSION_MAJOR[m
[32m+[m[32mchar const info_simulate_version[] = {[m
[32m+[m[32m  'I', 'N', 'F', 'O', ':',[m
[32m+[m[32m  's','i','m','u','l','a','t','e','_','v','e','r','s','i','o','n','[',[m
[32m+[m[32m  SIMULATE_VERSION_MAJOR,[m
[32m+[m[32m# ifdef SIMULATE_VERSION_MINOR[m
[32m+[m[32m  '.', SIMULATE_VERSION_MINOR,[m
[32m+[m[32m#  ifdef SIMULATE_VERSION_PATCH[m
[32m+[m[32m   '.', SIMULATE_VERSION_PATCH,[m
[32m+[m[32m#   ifdef SIMULATE_VERSION_TWEAK[m
[32m+[m[32m    '.', SIMULATE_VERSION_TWEAK,[m
[32m+[m[32m#   endif[m
[32m+[m[32m#  endif[m
[32m+[m[32m# endif[m
[32m+[m[32m  ']','\0'};[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32m/* Construct the string literal in pieces to prevent the source from[m
[32m+[m[32m   getting matched.  Store it in a pointer rather than an array[m
[32m+[m[32m   because some compilers will just produce instructions to fill the[m
[32m+[m[32m   array rather than assigning a pointer to a static array.  */[m
[32m+[m[32mchar const* info_platform = "INFO" ":" "platform[" PLATFORM_ID "]";[m
[32m+[m[32mchar const* info_arch = "INFO" ":" "arch[" ARCHITECTURE_ID "]";[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32m#if defined(_MSC_VER) && defined(_MSVC_LANG)[m
[32m+[m[32m#define CXX_STD _MSVC_LANG[m
[32m+[m[32m#else[m
[32m+[m[32m#define CXX_STD __cplusplus[m
[32m+[m[32m#endif[m
[32m+[m
[32m+[m[32mconst char* info_language_dialect_default = "INFO" ":" "dialect_default["[m
[32m+[m[32m#if CXX_STD > 201703L[m
[32m+[m[32m  "20"[m
[32m+[m[32m#elif CXX_STD >= 201703L[m
[32m+[m[32m  "17"[m
[32m+[m[32m#elif CXX_STD >= 201402L[m
[32m+[m[32m  "14"[m
[32m+[m[32m#elif CXX_STD >= 201103L[m
[32m+[m[32m  "11"[m
[32m+[m[32m#else[m
[32m+[m[32m  "98"[m
[32m+[m[32m#endif[m
[32m+[m[32m"]";[m
[32m+[m
[32m+[m[32m/*--------------------------------------------------------------------------*/[m
[32m+[m
[32m+[m[32mint main(int argc, char* argv[])[m
[32m+[m[32m{[m
[32m+[m[32m  int require = 0;[m
[32m+[m[32m  require += info_compiler[argc];[m
[32m+[m[32m  require += info_platform[argc];[m
[32m+[m[32m#ifdef COMPILER_VERSION_MAJOR[m
[32m+[m[32m  require += info_version[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#ifdef COMPILER_VERSION_INTERNAL[m
[32m+[m[32m  require += info_version_internal[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#ifdef SIMULATE_ID[m
[32m+[m[32m  require += info_simulate[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#ifdef SIMULATE_VERSION_MAJOR[m
[32m+[m[32m  require += info_simulate_version[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m#if defined(__CRAYXE) || defined(__CRAYXC)[m
[32m+[m[32m  require += info_cray[argc];[m
[32m+[m[32m#endif[m
[32m+[m[32m  require += info_language_dialect_default[argc];[m
[32m+[m[32m  (void)argv;[m
[32m+[m[32m  return require;[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/mm/CMakeFiles/CMakeDirectoryInformation.cmake b/kernel/mm/CMakeFiles/CMakeDirectoryInformation.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..d024a34[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/CMakeDirectoryInformation.cmake[m
[36m@@ -0,0 +1,16 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32m# Relative path conversion top directories.[m
[32m+[m[32mset(CMAKE_RELATIVE_PATH_TOP_SOURCE "/chos/kernel/mm")[m
[32m+[m[32mset(CMAKE_RELATIVE_PATH_TOP_BINARY "/chos/kernel/mm")[m
[32m+[m
[32m+[m[32m# Force unix paths in dependencies.[m
[32m+[m[32mset(CMAKE_FORCE_UNIX_PATHS 1)[m
[32m+[m
[32m+[m
[32m+[m[32m# The C and CXX include file regular expressions for this directory.[m
[32m+[m[32mset(CMAKE_C_INCLUDE_REGEX_SCAN "^.*$")[m
[32m+[m[32mset(CMAKE_C_INCLUDE_REGEX_COMPLAIN "^$")[m
[32m+[m[32mset(CMAKE_CXX_INCLUDE_REGEX_SCAN ${CMAKE_C_INCLUDE_REGEX_SCAN})[m
[32m+[m[32mset(CMAKE_CXX_INCLUDE_REGEX_COMPLAIN ${CMAKE_C_INCLUDE_REGEX_COMPLAIN})[m
[1mdiff --git a/kernel/mm/CMakeFiles/CMakeOutput.log b/kernel/mm/CMakeFiles/CMakeOutput.log[m
[1mnew file mode 100644[m
[1mindex 0000000..7a45dd9[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/CMakeOutput.log[m
[36m@@ -0,0 +1,469 @@[m
[32m+[m[32mThe system is: Linux - 5.0.0-23-generic - x86_64[m
[32m+[m[32mCompiling the C compiler identification source file "CMakeCCompilerId.c" succeeded.[m
[32m+[m[32mCompiler: /usr/bin/cc[m[41m [m
[32m+[m[32mBuild flags:[m[41m [m
[32m+[m[32mId flags:[m[41m  [m
[32m+[m
[32m+[m[32mThe output was:[m
[32m+[m[32m0[m
[32m+[m
[32m+[m
[32m+[m[32mCompilation of the C compiler identification source "CMakeCCompilerId.c" produced "a.out"[m
[32m+[m
[32m+[m[32mThe C compiler identification is GNU, found in "/chos/kernel/mm/CMakeFiles/3.15.5/CompilerIdC/a.out"[m
[32m+[m
[32m+[m[32mCompiling the CXX compiler identification source file "CMakeCXXCompilerId.cpp" succeeded.[m
[32m+[m[32mCompiler: /usr/bin/c++[m[41m [m
[32m+[m[32mBuild flags:[m[41m [m
[32m+[m[32mId flags:[m[41m  [m
[32m+[m
[32m+[m[32mThe output was:[m
[32m+[m[32m0[m
[32m+[m
[32m+[m
[32m+[m[32mCompilation of the CXX compiler identification source "CMakeCXXCompilerId.cpp" produced "a.out"[m
[32m+[m
[32m+[m[32mThe CXX compiler identification is GNU, found in "/chos/kernel/mm/CMakeFiles/3.15.5/CompilerIdCXX/a.out"[m
[32m+[m
[32m+[m[32mDetermining if the C compiler works passed with the following output:[m
[32m+[m[32mChange Dir: /chos/kernel/mm/CMakeFiles/CMakeTmp[m
[32m+[m
[32m+[m[32mRun Build Command(s):/usr/bin/make cmTC_c2c3c/fast && /usr/bin/make -f CMakeFiles/cmTC_c2c3c.dir/build.make CMakeFiles/cmTC_c2c3c.dir/build[m
[32m+[m[32mmake[1]: Entering directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m[32mBuilding C object CMakeFiles/cmTC_c2c3c.dir/testCCompiler.c.o[m
[32m+[m[32m/usr/bin/cc    -o CMakeFiles/cmTC_c2c3c.dir/testCCompiler.c.o   -c /chos/kernel/mm/CMakeFiles/CMakeTmp/testCCompiler.c[m
[32m+[m[32mLinking C executable cmTC_c2c3c[m
[32m+[m[32m/usr/local/bin/cmake -E cmake_link_script CMakeFiles/cmTC_c2c3c.dir/link.txt --verbose=1[m
[32m+[m[32m/usr/bin/cc      -rdynamic CMakeFiles/cmTC_c2c3c.dir/testCCompiler.c.o  -o cmTC_c2c3c[m[41m [m
[32m+[m[32mmake[1]: Leaving directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mDetecting C compiler ABI info compiled with the following output:[m
[32m+[m[32mChange Dir: /chos/kernel/mm/CMakeFiles/CMakeTmp[m
[32m+[m
[32m+[m[32mRun Build Command(s):/usr/bin/make cmTC_19967/fast && /usr/bin/make -f CMakeFiles/cmTC_19967.dir/build.make CMakeFiles/cmTC_19967.dir/build[m
[32m+[m[32mmake[1]: Entering directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m[32mBuilding C object CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o[m
[32m+[m[32m/usr/bin/cc   -v -o CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o   -c /usr/local/share/cmake-3.15/Modules/CMakeCCompilerABI.c[m
[32m+[m[32mUsing built-in specs.[m
[32m+[m[32mCOLLECT_GCC=/usr/bin/cc[m
[32m+[m[32mOFFLOAD_TARGET_NAMES=nvptx-none[m
[32m+[m[32mOFFLOAD_TARGET_DEFAULT=1[m
[32m+[m[32mTarget: x86_64-linux-gnu[m
[32m+[m[32mConfigured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu[m
[32m+[m[32mThread model: posix[m
[32m+[m[32mgcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1)[m[41m [m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o' '-c' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/cc1 -quiet -v -imultiarch x86_64-linux-gnu /usr/local/share/cmake-3.15/Modules/CMakeCCompilerABI.c -quiet -dumpbase CMakeCCompilerABI.c -mtune=generic -march=x86-64 -auxbase-strip CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o -version -fstack-protector-strong -Wformat -Wformat-security -o /tmp/ccm0xlEm.s[m
[32m+[m[32mGNU C11 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)[m
[32m+[m	[32mcompiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP[m
[32m+[m
[32m+[m[32mGGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072[m
[32m+[m[32mignoring nonexistent directory "/usr/local/include/x86_64-linux-gnu"[m
[32m+[m[32mignoring nonexistent directory "/usr/lib/gcc/x86_64-linux-gnu/7/../../../../x86_64-linux-gnu/include"[m
[32m+[m[32m#include "..." search starts here:[m
[32m+[m[32m#include <...> search starts here:[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/include[m
[32m+[m[32m /usr/local/include[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/include-fixed[m
[32m+[m[32m /usr/include/x86_64-linux-gnu[m
[32m+[m[32m /usr/include[m
[32m+[m[32mEnd of search list.[m
[32m+[m[32mGNU C11 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)[m
[32m+[m	[32mcompiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP[m
[32m+[m
[32m+[m[32mGGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072[m
[32m+[m[32mCompiler executable checksum: fa57db1fe2d756b22d454aa8428fd3bd[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o' '-c' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32m as -v --64 -o CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o /tmp/ccm0xlEm.s[m
[32m+[m[32mGNU assembler version 2.30 (x86_64-linux-gnu) using BFD version (GNU Binutils for Ubuntu) 2.30[m
[32m+[m[32mCOMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/[m
[32m+[m[32mLIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o' '-c' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32mLinking C executable cmTC_19967[m
[32m+[m[32m/usr/local/bin/cmake -E cmake_link_script CMakeFiles/cmTC_19967.dir/link.txt --verbose=1[m
[32m+[m[32m/usr/bin/cc     -v -rdynamic CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o  -o cmTC_19967[m[41m [m
[32m+[m[32mUsing built-in specs.[m
[32m+[m[32mCOLLECT_GCC=/usr/bin/cc[m
[32m+[m[32mCOLLECT_LTO_WRAPPER=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper[m
[32m+[m[32mOFFLOAD_TARGET_NAMES=nvptx-none[m
[32m+[m[32mOFFLOAD_TARGET_DEFAULT=1[m
[32m+[m[32mTarget: x86_64-linux-gnu[m
[32m+[m[32mConfigured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu[m
[32m+[m[32mThread model: posix[m
[32m+[m[32mgcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1)[m[41m [m
[32m+[m[32mCOMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/[m
[32m+[m[32mLIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-rdynamic' '-o' 'cmTC_19967' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/collect2 -plugin /usr/lib/gcc/x86_64-linux-gnu/7/liblto_plugin.so -plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper -plugin-opt=-fresolution=/tmp/ccIOA6mE.res -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lc -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lgcc_s --sysroot=/ --build-id --eh-frame-hdr -m elf_x86_64 --hash-style=gnu --as-needed -export-dynamic -dynamic-linker /lib64/ld-linux-x86-64.so.2 -pie -z now -z relro -o cmTC_19967 /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/7/crtbeginS.o -L/usr/lib/gcc/x86_64-linux-gnu/7 -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib -L/lib/x86_64-linux-gnu -L/lib/../lib -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib -L/usr/lib/gcc/x86_64-linux-gnu/7/../../.. CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o -lgcc --push-state --as-needed -lgcc_s --pop-state -lc -lgcc --push-state --as-needed -lgcc_s --pop-state /usr/lib/gcc/x86_64-linux-gnu/7/crtendS.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crtn.o[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-rdynamic' '-o' 'cmTC_19967' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32mmake[1]: Leaving directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mParsed C implicit include dir info from above output: rv=done[m
[32m+[m[32m  found start of include info[m
[32m+[m[32m  found start of implicit include info[m
[32m+[m[32m    add: [/usr/lib/gcc/x86_64-linux-gnu/7/include][m
[32m+[m[32m    add: [/usr/local/include][m
[32m+[m[32m    add: [/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed][m
[32m+[m[32m    add: [/usr/include/x86_64-linux-gnu][m
[32m+[m[32m    add: [/usr/include][m
[32m+[m[32m  end of search list found[m
[32m+[m[32m  collapse include dir [/usr/lib/gcc/x86_64-linux-gnu/7/include] ==> [/usr/lib/gcc/x86_64-linux-gnu/7/include][m
[32m+[m[32m  collapse include dir [/usr/local/include] ==> [/usr/local/include][m
[32m+[m[32m  collapse include dir [/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed] ==> [/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed][m
[32m+[m[32m  collapse include dir [/usr/include/x86_64-linux-gnu] ==> [/usr/include/x86_64-linux-gnu][m
[32m+[m[32m  collapse include dir [/usr/include] ==> [/usr/include][m
[32m+[m[32m  implicit include dirs: [/usr/lib/gcc/x86_64-linux-gnu/7/include;/usr/local/include;/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed;/usr/include/x86_64-linux-gnu;/usr/include][m
[32m+[m
[32m+[m
[32m+[m[32mParsed C implicit link information from above output:[m
[32m+[m[32m  link line regex: [^( *|.*[/\])(ld|CMAKE_LINK_STARTFILE-NOTFOUND|([^/\]+-)?ld|collect2)[^/\]*( |$)][m
[32m+[m[32m  ignore line: [Change Dir: /chos/kernel/mm/CMakeFiles/CMakeTmp][m
[32m+[m[32m  ignore line: [][m
[32m+[m[32m  ignore line: [Run Build Command(s):/usr/bin/make cmTC_19967/fast && /usr/bin/make -f CMakeFiles/cmTC_19967.dir/build.make CMakeFiles/cmTC_19967.dir/build][m
[32m+[m[32m  ignore line: [make[1]: Entering directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'][m
[32m+[m[32m  ignore line: [Building C object CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o][m
[32m+[m[32m  ignore line: [/usr/bin/cc   -v -o CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o   -c /usr/local/share/cmake-3.15/Modules/CMakeCCompilerABI.c][m
[32m+[m[32m  ignore line: [Using built-in specs.][m
[32m+[m[32m  ignore line: [COLLECT_GCC=/usr/bin/cc][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_NAMES=nvptx-none][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_DEFAULT=1][m
[32m+[m[32m  ignore line: [Target: x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Configured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Thread model: posix][m
[32m+[m[32m  ignore line: [gcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1) ][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o' '-c' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  ignore line: [ /usr/lib/gcc/x86_64-linux-gnu/7/cc1 -quiet -v -imultiarch x86_64-linux-gnu /usr/local/share/cmake-3.15/Modules/CMakeCCompilerABI.c -quiet -dumpbase CMakeCCompilerABI.c -mtune=generic -march=x86-64 -auxbase-strip CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o -version -fstack-protector-strong -Wformat -Wformat-security -o /tmp/ccm0xlEm.s][m
[32m+[m[32m  ignore line: [GNU C11 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)][m
[32m+[m[32m  ignore line: [	compiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP][m
[32m+[m[32m  ignore line: [][m
[32m+[m[32m  ignore line: [GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072][m
[32m+[m[32m  ignore line: [ignoring nonexistent directory "/usr/local/include/x86_64-linux-gnu"][m
[32m+[m[32m  ignore line: [ignoring nonexistent directory "/usr/lib/gcc/x86_64-linux-gnu/7/../../../../x86_64-linux-gnu/include"][m
[32m+[m[32m  ignore line: [#include "..." search starts here:][m
[32m+[m[32m  ignore line: [#include <...> search starts here:][m
[32m+[m[32m  ignore line: [ /usr/lib/gcc/x86_64-linux-gnu/7/include][m
[32m+[m[32m  ignore line: [ /usr/local/include][m
[32m+[m[32m  ignore line: [ /usr/lib/gcc/x86_64-linux-gnu/7/include-fixed][m
[32m+[m[32m  ignore line: [ /usr/include/x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [ /usr/include][m
[32m+[m[32m  ignore line: [End of search list.][m
[32m+[m[32m  ignore line: [GNU C11 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)][m
[32m+[m[32m  ignore line: [	compiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP][m
[32m+[m[32m  ignore line: [][m
[32m+[m[32m  ignore line: [GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072][m
[32m+[m[32m  ignore line: [Compiler executable checksum: fa57db1fe2d756b22d454aa8428fd3bd][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o' '-c' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  ignore line: [ as -v --64 -o CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o /tmp/ccm0xlEm.s][m
[32m+[m[32m  ignore line: [GNU assembler version 2.30 (x86_64-linux-gnu) using BFD version (GNU Binutils for Ubuntu) 2.30][m
[32m+[m[32m  ignore line: [COMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/][m
[32m+[m[32m  ignore line: [LIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o' '-c' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  ignore line: [Linking C executable cmTC_19967][m
[32m+[m[32m  ignore line: [/usr/local/bin/cmake -E cmake_link_script CMakeFiles/cmTC_19967.dir/link.txt --verbose=1][m
[32m+[m[32m  ignore line: [/usr/bin/cc     -v -rdynamic CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o  -o cmTC_19967 ][m
[32m+[m[32m  ignore line: [Using built-in specs.][m
[32m+[m[32m  ignore line: [COLLECT_GCC=/usr/bin/cc][m
[32m+[m[32m  ignore line: [COLLECT_LTO_WRAPPER=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_NAMES=nvptx-none][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_DEFAULT=1][m
[32m+[m[32m  ignore line: [Target: x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Configured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Thread model: posix][m
[32m+[m[32m  ignore line: [gcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1) ][m
[32m+[m[32m  ignore line: [COMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/][m
[32m+[m[32m  ignore line: [LIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-rdynamic' '-o' 'cmTC_19967' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  link line: [ /usr/lib/gcc/x86_64-linux-gnu/7/collect2 -plugin /usr/lib/gcc/x86_64-linux-gnu/7/liblto_plugin.so -plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper -plugin-opt=-fresolution=/tmp/ccIOA6mE.res -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lc -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lgcc_s --sysroot=/ --build-id --eh-frame-hdr -m elf_x86_64 --hash-style=gnu --as-needed -export-dynamic -dynamic-linker /lib64/ld-linux-x86-64.so.2 -pie -z now -z relro -o cmTC_19967 /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/7/crtbeginS.o -L/usr/lib/gcc/x86_64-linux-gnu/7 -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib -L/lib/x86_64-linux-gnu -L/lib/../lib -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib -L/usr/lib/gcc/x86_64-linux-gnu/7/../../.. CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o -lgcc --push-state --as-needed -lgcc_s --pop-state -lc -lgcc --push-state --as-needed -lgcc_s --pop-state /usr/lib/gcc/x86_64-linux-gnu/7/crtendS.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crtn.o][m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/collect2] ==> ignore[m
[32m+[m[32m    arg [-plugin] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/liblto_plugin.so] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-fresolution=/tmp/ccIOA6mE.res] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc_s] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lc] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc_s] ==> ignore[m
[32m+[m[32m    arg [--sysroot=/] ==> ignore[m
[32m+[m[32m    arg [--build-id] ==> ignore[m
[32m+[m[32m    arg [--eh-frame-hdr] ==> ignore[m
[32m+[m[32m    arg [-m] ==> ignore[m
[32m+[m[32m    arg [elf_x86_64] ==> ignore[m
[32m+[m[32m    arg [--hash-style=gnu] ==> ignore[m
[32m+[m[32m    arg [--as-needed] ==> ignore[m
[32m+[m[32m    arg [-export-dynamic] ==> ignore[m
[32m+[m[32m    arg [-dynamic-linker] ==> ignore[m
[32m+[m[32m    arg [/lib64/ld-linux-x86-64.so.2] ==> ignore[m
[32m+[m[32m    arg [-pie] ==> ignore[m
[32m+[m[32m    arg [-znow] ==> ignore[m
[32m+[m[32m    arg [-zrelro] ==> ignore[m
[32m+[m[32m    arg [-o] ==> ignore[m
[32m+[m[32m    arg [cmTC_19967] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crti.o] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/crtbeginS.o] ==> ignore[m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7][m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu][m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib][m
[32m+[m[32m    arg [-L/lib/x86_64-linux-gnu] ==> dir [/lib/x86_64-linux-gnu][m
[32m+[m[32m    arg [-L/lib/../lib] ==> dir [/lib/../lib][m
[32m+[m[32m    arg [-L/usr/lib/x86_64-linux-gnu] ==> dir [/usr/lib/x86_64-linux-gnu][m
[32m+[m[32m    arg [-L/usr/lib/../lib] ==> dir [/usr/lib/../lib][m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7/../../..] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../..][m
[32m+[m[32m    arg [CMakeFiles/cmTC_19967.dir/CMakeCCompilerABI.c.o] ==> ignore[m
[32m+[m[32m    arg [-lgcc] ==> lib [gcc][m
[32m+[m[32m    arg [--push-state] ==> ignore[m
[32m+[m[32m    arg [--as-needed] ==> ignore[m
[32m+[m[32m    arg [-lgcc_s] ==> lib [gcc_s][m
[32m+[m[32m    arg [--pop-state] ==> ignore[m
[32m+[m[32m    arg [-lc] ==> lib [c][m
[32m+[m[32m    arg [-lgcc] ==> lib [gcc][m
[32m+[m[32m    arg [--push-state] ==> ignore[m
[32m+[m[32m    arg [--as-needed] ==> ignore[m
[32m+[m[32m    arg [-lgcc_s] ==> lib [gcc_s][m
[32m+[m[32m    arg [--pop-state] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/crtendS.o] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crtn.o] ==> ignore[m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7] ==> [/usr/lib/gcc/x86_64-linux-gnu/7][m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu] ==> [/usr/lib/x86_64-linux-gnu][m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib] ==> [/usr/lib][m
[32m+[m[32m  collapse library dir [/lib/x86_64-linux-gnu] ==> [/lib/x86_64-linux-gnu][m
[32m+[m[32m  collapse library dir [/lib/../lib] ==> [/lib][m
[32m+[m[32m  collapse library dir [/usr/lib/x86_64-linux-gnu] ==> [/usr/lib/x86_64-linux-gnu][m
[32m+[m[32m  collapse library dir [/usr/lib/../lib] ==> [/usr/lib][m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../..] ==> [/usr/lib][m
[32m+[m[32m  implicit libs: [gcc;gcc_s;c;gcc;gcc_s][m
[32m+[m[32m  implicit dirs: [/usr/lib/gcc/x86_64-linux-gnu/7;/usr/lib/x86_64-linux-gnu;/usr/lib;/lib/x86_64-linux-gnu;/lib][m
[32m+[m[32m  implicit fwks: [][m
[32m+[m
[32m+[m
[32m+[m[32mDetermining if the CXX compiler works passed with the following output:[m
[32m+[m[32mChange Dir: /chos/kernel/mm/CMakeFiles/CMakeTmp[m
[32m+[m
[32m+[m[32mRun Build Command(s):/usr/bin/make cmTC_c2310/fast && /usr/bin/make -f CMakeFiles/cmTC_c2310.dir/build.make CMakeFiles/cmTC_c2310.dir/build[m
[32m+[m[32mmake[1]: Entering directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m[32mBuilding CXX object CMakeFiles/cmTC_c2310.dir/testCXXCompiler.cxx.o[m
[32m+[m[32m/usr/bin/c++     -o CMakeFiles/cmTC_c2310.dir/testCXXCompiler.cxx.o -c /chos/kernel/mm/CMakeFiles/CMakeTmp/testCXXCompiler.cxx[m
[32m+[m[32mLinking CXX executable cmTC_c2310[m
[32m+[m[32m/usr/local/bin/cmake -E cmake_link_script CMakeFiles/cmTC_c2310.dir/link.txt --verbose=1[m
[32m+[m[32m/usr/bin/c++       -rdynamic CMakeFiles/cmTC_c2310.dir/testCXXCompiler.cxx.o  -o cmTC_c2310[m[41m [m
[32m+[m[32mmake[1]: Leaving directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mDetecting CXX compiler ABI info compiled with the following output:[m
[32m+[m[32mChange Dir: /chos/kernel/mm/CMakeFiles/CMakeTmp[m
[32m+[m
[32m+[m[32mRun Build Command(s):/usr/bin/make cmTC_69895/fast && /usr/bin/make -f CMakeFiles/cmTC_69895.dir/build.make CMakeFiles/cmTC_69895.dir/build[m
[32m+[m[32mmake[1]: Entering directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m[32mBuilding CXX object CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o[m
[32m+[m[32m/usr/bin/c++    -v -o CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o -c /usr/local/share/cmake-3.15/Modules/CMakeCXXCompilerABI.cpp[m
[32m+[m[32mUsing built-in specs.[m
[32m+[m[32mCOLLECT_GCC=/usr/bin/c++[m
[32m+[m[32mOFFLOAD_TARGET_NAMES=nvptx-none[m
[32m+[m[32mOFFLOAD_TARGET_DEFAULT=1[m
[32m+[m[32mTarget: x86_64-linux-gnu[m
[32m+[m[32mConfigured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu[m
[32m+[m[32mThread model: posix[m
[32m+[m[32mgcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1)[m[41m [m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o' '-c' '-shared-libgcc' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/cc1plus -quiet -v -imultiarch x86_64-linux-gnu -D_GNU_SOURCE /usr/local/share/cmake-3.15/Modules/CMakeCXXCompilerABI.cpp -quiet -dumpbase CMakeCXXCompilerABI.cpp -mtune=generic -march=x86-64 -auxbase-strip CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o -version -fstack-protector-strong -Wformat -Wformat-security -o /tmp/ccxwvm29.s[m
[32m+[m[32mGNU C++14 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)[m
[32m+[m	[32mcompiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP[m
[32m+[m
[32m+[m[32mGGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072[m
[32m+[m[32mignoring duplicate directory "/usr/include/x86_64-linux-gnu/c++/7"[m
[32m+[m[32mignoring nonexistent directory "/usr/local/include/x86_64-linux-gnu"[m
[32m+[m[32mignoring nonexistent directory "/usr/lib/gcc/x86_64-linux-gnu/7/../../../../x86_64-linux-gnu/include"[m
[32m+[m[32m#include "..." search starts here:[m
[32m+[m[32m#include <...> search starts here:[m
[32m+[m[32m /usr/include/c++/7[m
[32m+[m[32m /usr/include/x86_64-linux-gnu/c++/7[m
[32m+[m[32m /usr/include/c++/7/backward[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/include[m
[32m+[m[32m /usr/local/include[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/include-fixed[m
[32m+[m[32m /usr/include/x86_64-linux-gnu[m
[32m+[m[32m /usr/include[m
[32m+[m[32mEnd of search list.[m
[32m+[m[32mGNU C++14 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)[m
[32m+[m	[32mcompiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP[m
[32m+[m
[32m+[m[32mGGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072[m
[32m+[m[32mCompiler executable checksum: 38816e3807cdcb3c59571e251bd6c090[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o' '-c' '-shared-libgcc' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32m as -v --64 -o CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o /tmp/ccxwvm29.s[m
[32m+[m[32mGNU assembler version 2.30 (x86_64-linux-gnu) using BFD version (GNU Binutils for Ubuntu) 2.30[m
[32m+[m[32mCOMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/[m
[32m+[m[32mLIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o' '-c' '-shared-libgcc' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32mLinking CXX executable cmTC_69895[m
[32m+[m[32m/usr/local/bin/cmake -E cmake_link_script CMakeFiles/cmTC_69895.dir/link.txt --verbose=1[m
[32m+[m[32m/usr/bin/c++      -v -rdynamic CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o  -o cmTC_69895[m[41m [m
[32m+[m[32mUsing built-in specs.[m
[32m+[m[32mCOLLECT_GCC=/usr/bin/c++[m
[32m+[m[32mCOLLECT_LTO_WRAPPER=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper[m
[32m+[m[32mOFFLOAD_TARGET_NAMES=nvptx-none[m
[32m+[m[32mOFFLOAD_TARGET_DEFAULT=1[m
[32m+[m[32mTarget: x86_64-linux-gnu[m
[32m+[m[32mConfigured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu[m
[32m+[m[32mThread model: posix[m
[32m+[m[32mgcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1)[m[41m [m
[32m+[m[32mCOMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/[m
[32m+[m[32mLIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-rdynamic' '-o' 'cmTC_69895' '-shared-libgcc' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32m /usr/lib/gcc/x86_64-linux-gnu/7/collect2 -plugin /usr/lib/gcc/x86_64-linux-gnu/7/liblto_plugin.so -plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper -plugin-opt=-fresolution=/tmp/ccWrNcNp.res -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lc -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lgcc --sysroot=/ --build-id --eh-frame-hdr -m elf_x86_64 --hash-style=gnu --as-needed -export-dynamic -dynamic-linker /lib64/ld-linux-x86-64.so.2 -pie -z now -z relro -o cmTC_69895 /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/7/crtbeginS.o -L/usr/lib/gcc/x86_64-linux-gnu/7 -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib -L/lib/x86_64-linux-gnu -L/lib/../lib -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib -L/usr/lib/gcc/x86_64-linux-gnu/7/../../.. CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o -lstdc++ -lm -lgcc_s -lgcc -lc -lgcc_s -lgcc /usr/lib/gcc/x86_64-linux-gnu/7/crtendS.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crtn.o[m
[32m+[m[32mCOLLECT_GCC_OPTIONS='-v' '-rdynamic' '-o' 'cmTC_69895' '-shared-libgcc' '-mtune=generic' '-march=x86-64'[m
[32m+[m[32mmake[1]: Leaving directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mParsed CXX implicit include dir info from above output: rv=done[m
[32m+[m[32m  found start of include info[m
[32m+[m[32m  found start of implicit include info[m
[32m+[m[32m    add: [/usr/include/c++/7][m
[32m+[m[32m    add: [/usr/include/x86_64-linux-gnu/c++/7][m
[32m+[m[32m    add: [/usr/include/c++/7/backward][m
[32m+[m[32m    add: [/usr/lib/gcc/x86_64-linux-gnu/7/include][m
[32m+[m[32m    add: [/usr/local/include][m
[32m+[m[32m    add: [/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed][m
[32m+[m[32m    add: [/usr/include/x86_64-linux-gnu][m
[32m+[m[32m    add: [/usr/include][m
[32m+[m[32m  end of search list found[m
[32m+[m[32m  collapse include dir [/usr/include/c++/7] ==> [/usr/include/c++/7][m
[32m+[m[32m  collapse include dir [/usr/include/x86_64-linux-gnu/c++/7] ==> [/usr/include/x86_64-linux-gnu/c++/7][m
[32m+[m[32m  collapse include dir [/usr/include/c++/7/backward] ==> [/usr/include/c++/7/backward][m
[32m+[m[32m  collapse include dir [/usr/lib/gcc/x86_64-linux-gnu/7/include] ==> [/usr/lib/gcc/x86_64-linux-gnu/7/include][m
[32m+[m[32m  collapse include dir [/usr/local/include] ==> [/usr/local/include][m
[32m+[m[32m  collapse include dir [/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed] ==> [/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed][m
[32m+[m[32m  collapse include dir [/usr/include/x86_64-linux-gnu] ==> [/usr/include/x86_64-linux-gnu][m
[32m+[m[32m  collapse include dir [/usr/include] ==> [/usr/include][m
[32m+[m[32m  implicit include dirs: [/usr/include/c++/7;/usr/include/x86_64-linux-gnu/c++/7;/usr/include/c++/7/backward;/usr/lib/gcc/x86_64-linux-gnu/7/include;/usr/local/include;/usr/lib/gcc/x86_64-linux-gnu/7/include-fixed;/usr/include/x86_64-linux-gnu;/usr/include][m
[32m+[m
[32m+[m
[32m+[m[32mParsed CXX implicit link information from above output:[m
[32m+[m[32m  link line regex: [^( *|.*[/\])(ld|CMAKE_LINK_STARTFILE-NOTFOUND|([^/\]+-)?ld|collect2)[^/\]*( |$)][m
[32m+[m[32m  ignore line: [Change Dir: /chos/kernel/mm/CMakeFiles/CMakeTmp][m
[32m+[m[32m  ignore line: [][m
[32m+[m[32m  ignore line: [Run Build Command(s):/usr/bin/make cmTC_69895/fast && /usr/bin/make -f CMakeFiles/cmTC_69895.dir/build.make CMakeFiles/cmTC_69895.dir/build][m
[32m+[m[32m  ignore line: [make[1]: Entering directory '/chos/kernel/mm/CMakeFiles/CMakeTmp'][m
[32m+[m[32m  ignore line: [Building CXX object CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o][m
[32m+[m[32m  ignore line: [/usr/bin/c++    -v -o CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o -c /usr/local/share/cmake-3.15/Modules/CMakeCXXCompilerABI.cpp][m
[32m+[m[32m  ignore line: [Using built-in specs.][m
[32m+[m[32m  ignore line: [COLLECT_GCC=/usr/bin/c++][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_NAMES=nvptx-none][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_DEFAULT=1][m
[32m+[m[32m  ignore line: [Target: x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Configured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Thread model: posix][m
[32m+[m[32m  ignore line: [gcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1) ][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o' '-c' '-shared-libgcc' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  ignore line: [ /usr/lib/gcc/x86_64-linux-gnu/7/cc1plus -quiet -v -imultiarch x86_64-linux-gnu -D_GNU_SOURCE /usr/local/share/cmake-3.15/Modules/CMakeCXXCompilerABI.cpp -quiet -dumpbase CMakeCXXCompilerABI.cpp -mtune=generic -march=x86-64 -auxbase-strip CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o -version -fstack-protector-strong -Wformat -Wformat-security -o /tmp/ccxwvm29.s][m
[32m+[m[32m  ignore line: [GNU C++14 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)][m
[32m+[m[32m  ignore line: [	compiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP][m
[32m+[m[32m  ignore line: [][m
[32m+[m[32m  ignore line: [GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072][m
[32m+[m[32m  ignore line: [ignoring duplicate directory "/usr/include/x86_64-linux-gnu/c++/7"][m
[32m+[m[32m  ignore line: [ignoring nonexistent directory "/usr/local/include/x86_64-linux-gnu"][m
[32m+[m[32m  ignore line: [ignoring nonexistent directory "/usr/lib/gcc/x86_64-linux-gnu/7/../../../../x86_64-linux-gnu/include"][m
[32m+[m[32m  ignore line: [#include "..." search starts here:][m
[32m+[m[32m  ignore line: [#include <...> search starts here:][m
[32m+[m[32m  ignore line: [ /usr/include/c++/7][m
[32m+[m[32m  ignore line: [ /usr/include/x86_64-linux-gnu/c++/7][m
[32m+[m[32m  ignore line: [ /usr/include/c++/7/backward][m
[32m+[m[32m  ignore line: [ /usr/lib/gcc/x86_64-linux-gnu/7/include][m
[32m+[m[32m  ignore line: [ /usr/local/include][m
[32m+[m[32m  ignore line: [ /usr/lib/gcc/x86_64-linux-gnu/7/include-fixed][m
[32m+[m[32m  ignore line: [ /usr/include/x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [ /usr/include][m
[32m+[m[32m  ignore line: [End of search list.][m
[32m+[m[32m  ignore line: [GNU C++14 (Ubuntu 7.4.0-1ubuntu1~18.04.1) version 7.4.0 (x86_64-linux-gnu)][m
[32m+[m[32m  ignore line: [	compiled by GNU C version 7.4.0, GMP version 6.1.2, MPFR version 4.0.1, MPC version 1.1.0, isl version isl-0.19-GMP][m
[32m+[m[32m  ignore line: [][m
[32m+[m[32m  ignore line: [GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072][m
[32m+[m[32m  ignore line: [Compiler executable checksum: 38816e3807cdcb3c59571e251bd6c090][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o' '-c' '-shared-libgcc' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  ignore line: [ as -v --64 -o CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o /tmp/ccxwvm29.s][m
[32m+[m[32m  ignore line: [GNU assembler version 2.30 (x86_64-linux-gnu) using BFD version (GNU Binutils for Ubuntu) 2.30][m
[32m+[m[32m  ignore line: [COMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/][m
[32m+[m[32m  ignore line: [LIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-o' 'CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o' '-c' '-shared-libgcc' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  ignore line: [Linking CXX executable cmTC_69895][m
[32m+[m[32m  ignore line: [/usr/local/bin/cmake -E cmake_link_script CMakeFiles/cmTC_69895.dir/link.txt --verbose=1][m
[32m+[m[32m  ignore line: [/usr/bin/c++      -v -rdynamic CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o  -o cmTC_69895 ][m
[32m+[m[32m  ignore line: [Using built-in specs.][m
[32m+[m[32m  ignore line: [COLLECT_GCC=/usr/bin/c++][m
[32m+[m[32m  ignore line: [COLLECT_LTO_WRAPPER=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_NAMES=nvptx-none][m
[32m+[m[32m  ignore line: [OFFLOAD_TARGET_DEFAULT=1][m
[32m+[m[32m  ignore line: [Target: x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Configured with: ../src/configure -v --with-pkgversion='Ubuntu 7.4.0-1ubuntu1~18.04.1' --with-bugurl=file:///usr/share/doc/gcc-7/README.Bugs --enable-languages=c,ada,c++,go,brig,d,fortran,objc,obj-c++ --prefix=/usr --with-gcc-major-version-only --program-suffix=-7 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --enable-default-pie --with-system-zlib --with-target-system-zlib --enable-objc-gc=auto --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu][m
[32m+[m[32m  ignore line: [Thread model: posix][m
[32m+[m[32m  ignore line: [gcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1) ][m
[32m+[m[32m  ignore line: [COMPILER_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/][m
[32m+[m[32m  ignore line: [LIBRARY_PATH=/usr/lib/gcc/x86_64-linux-gnu/7/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib/:/lib/x86_64-linux-gnu/:/lib/../lib/:/usr/lib/x86_64-linux-gnu/:/usr/lib/../lib/:/usr/lib/gcc/x86_64-linux-gnu/7/../../../:/lib/:/usr/lib/][m
[32m+[m[32m  ignore line: [COLLECT_GCC_OPTIONS='-v' '-rdynamic' '-o' 'cmTC_69895' '-shared-libgcc' '-mtune=generic' '-march=x86-64'][m
[32m+[m[32m  link line: [ /usr/lib/gcc/x86_64-linux-gnu/7/collect2 -plugin /usr/lib/gcc/x86_64-linux-gnu/7/liblto_plugin.so -plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper -plugin-opt=-fresolution=/tmp/ccWrNcNp.res -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lgcc -plugin-opt=-pass-through=-lc -plugin-opt=-pass-through=-lgcc_s -plugin-opt=-pass-through=-lgcc --sysroot=/ --build-id --eh-frame-hdr -m elf_x86_64 --hash-style=gnu --as-needed -export-dynamic -dynamic-linker /lib64/ld-linux-x86-64.so.2 -pie -z now -z relro -o cmTC_69895 /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crti.o /usr/lib/gcc/x86_64-linux-gnu/7/crtbeginS.o -L/usr/lib/gcc/x86_64-linux-gnu/7 -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu -L/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib -L/lib/x86_64-linux-gnu -L/lib/../lib -L/usr/lib/x86_64-linux-gnu -L/usr/lib/../lib -L/usr/lib/gcc/x86_64-linux-gnu/7/../../.. CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o -lstdc++ -lm -lgcc_s -lgcc -lc -lgcc_s -lgcc /usr/lib/gcc/x86_64-linux-gnu/7/crtendS.o /usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crtn.o][m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/collect2] ==> ignore[m
[32m+[m[32m    arg [-plugin] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/liblto_plugin.so] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=/usr/lib/gcc/x86_64-linux-gnu/7/lto-wrapper] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-fresolution=/tmp/ccWrNcNp.res] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc_s] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lc] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc_s] ==> ignore[m
[32m+[m[32m    arg [-plugin-opt=-pass-through=-lgcc] ==> ignore[m
[32m+[m[32m    arg [--sysroot=/] ==> ignore[m
[32m+[m[32m    arg [--build-id] ==> ignore[m
[32m+[m[32m    arg [--eh-frame-hdr] ==> ignore[m
[32m+[m[32m    arg [-m] ==> ignore[m
[32m+[m[32m    arg [elf_x86_64] ==> ignore[m
[32m+[m[32m    arg [--hash-style=gnu] ==> ignore[m
[32m+[m[32m    arg [--as-needed] ==> ignore[m
[32m+[m[32m    arg [-export-dynamic] ==> ignore[m
[32m+[m[32m    arg [-dynamic-linker] ==> ignore[m
[32m+[m[32m    arg [/lib64/ld-linux-x86-64.so.2] ==> ignore[m
[32m+[m[32m    arg [-pie] ==> ignore[m
[32m+[m[32m    arg [-znow] ==> ignore[m
[32m+[m[32m    arg [-zrelro] ==> ignore[m
[32m+[m[32m    arg [-o] ==> ignore[m
[32m+[m[32m    arg [cmTC_69895] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/Scrt1.o] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crti.o] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/crtbeginS.o] ==> ignore[m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7][m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu][m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib][m
[32m+[m[32m    arg [-L/lib/x86_64-linux-gnu] ==> dir [/lib/x86_64-linux-gnu][m
[32m+[m[32m    arg [-L/lib/../lib] ==> dir [/lib/../lib][m
[32m+[m[32m    arg [-L/usr/lib/x86_64-linux-gnu] ==> dir [/usr/lib/x86_64-linux-gnu][m
[32m+[m[32m    arg [-L/usr/lib/../lib] ==> dir [/usr/lib/../lib][m
[32m+[m[32m    arg [-L/usr/lib/gcc/x86_64-linux-gnu/7/../../..] ==> dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../..][m
[32m+[m[32m    arg [CMakeFiles/cmTC_69895.dir/CMakeCXXCompilerABI.cpp.o] ==> ignore[m
[32m+[m[32m    arg [-lstdc++] ==> lib [stdc++][m
[32m+[m[32m    arg [-lm] ==> lib [m][m
[32m+[m[32m    arg [-lgcc_s] ==> lib [gcc_s][m
[32m+[m[32m    arg [-lgcc] ==> lib [gcc][m
[32m+[m[32m    arg [-lc] ==> lib [c][m
[32m+[m[32m    arg [-lgcc_s] ==> lib [gcc_s][m
[32m+[m[32m    arg [-lgcc] ==> lib [gcc][m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/crtendS.o] ==> ignore[m
[32m+[m[32m    arg [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu/crtn.o] ==> ignore[m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7] ==> [/usr/lib/gcc/x86_64-linux-gnu/7][m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../x86_64-linux-gnu] ==> [/usr/lib/x86_64-linux-gnu][m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../../../lib] ==> [/usr/lib][m
[32m+[m[32m  collapse library dir [/lib/x86_64-linux-gnu] ==> [/lib/x86_64-linux-gnu][m
[32m+[m[32m  collapse library dir [/lib/../lib] ==> [/lib][m
[32m+[m[32m  collapse library dir [/usr/lib/x86_64-linux-gnu] ==> [/usr/lib/x86_64-linux-gnu][m
[32m+[m[32m  collapse library dir [/usr/lib/../lib] ==> [/usr/lib][m
[32m+[m[32m  collapse library dir [/usr/lib/gcc/x86_64-linux-gnu/7/../../..] ==> [/usr/lib][m
[32m+[m[32m  implicit libs: [stdc++;m;gcc_s;gcc;c;gcc_s;gcc][m
[32m+[m[32m  implicit dirs: [/usr/lib/gcc/x86_64-linux-gnu/7;/usr/lib/x86_64-linux-gnu;/usr/lib;/lib/x86_64-linux-gnu;/lib][m
[32m+[m[32m  implicit fwks: [][m
[32m+[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/Makefile.cmake b/kernel/mm/CMakeFiles/Makefile.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..9de9da5[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Makefile.cmake[m
[36m@@ -0,0 +1,120 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32m# The generator used is:[m
[32m+[m[32mset(CMAKE_DEPENDS_GENERATOR "Unix Makefiles")[m
[32m+[m
[32m+[m[32m# The top level Makefile was generated from the following files:[m
[32m+[m[32mset(CMAKE_MAKEFILE_DEPENDS[m
[32m+[m[32m  "CMakeCache.txt"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeCCompiler.cmake"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeCXXCompiler.cmake"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeSystem.cmake"[m
[32m+[m[32m  "CMakeLists.txt"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCCompiler.cmake.in"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCCompilerABI.c"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCInformation.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCXXCompiler.cmake.in"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCXXCompilerABI.cpp"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCXXInformation.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCheckCompilerFlagCommonPatterns.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCommonLanguageInclude.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeCompilerIdDetection.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineCCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineCXXCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineCompileFeatures.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineCompilerABI.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineCompilerId.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeDetermineSystem.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeFindBinUtils.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeGenericSystem.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeInitializeConfigs.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeLanguageInformation.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeParseImplicitIncludeInfo.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeParseImplicitLinkInfo.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeSystem.cmake.in"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeSystemSpecificInformation.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeSystemSpecificInitialize.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeTestCCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeTestCXXCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeTestCompilerCommon.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/CMakeUnixFindMake.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/ADSP-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/ARMCC-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/ARMClang-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/AppleClang-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Borland-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Bruce-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/CMakeCommonCompilerMacros.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Clang-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Clang-DetermineCompilerInternal.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Comeau-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Compaq-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Compaq-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Cray-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Embarcadero-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Fujitsu-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GHS-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GNU-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GNU-C.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GNU-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GNU-CXX.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GNU-FindBinUtils.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/GNU.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/HP-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/HP-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/IAR-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/IBMCPP-C-DetermineVersionInternal.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/IBMCPP-CXX-DetermineVersionInternal.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Intel-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/MSVC-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/NVIDIA-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/OpenWatcom-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/PGI-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/PathScale-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/SCO-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/SDCC-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/SunPro-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/SunPro-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/TI-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/TinyCC-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/VisualAge-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/VisualAge-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/Watcom-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/XL-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/XL-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/XLClang-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/XLClang-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/zOS-C-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Compiler/zOS-CXX-DetermineCompiler.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Internal/CMakeCheckCompilerFlag.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Internal/FeatureTesting.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Platform/Linux-Determine-CXX.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Platform/Linux-GNU-C.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Platform/Linux-GNU-CXX.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Platform/Linux-GNU.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Platform/Linux.cmake"[m
[32m+[m[32m  "/usr/local/share/cmake-3.15/Modules/Platform/UnixPaths.cmake"[m
[32m+[m[32m  )[m
[32m+[m
[32m+[m[32m# The corresponding makefile is:[m
[32m+[m[32mset(CMAKE_MAKEFILE_OUTPUTS[m
[32m+[m[32m  "Makefile"[m
[32m+[m[32m  "CMakeFiles/cmake.check_cache"[m
[32m+[m[32m  )[m
[32m+[m
[32m+[m[32m# Byproducts of CMake generate step:[m
[32m+[m[32mset(CMAKE_MAKEFILE_PRODUCTS[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeSystem.cmake"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeCCompiler.cmake"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeCXXCompiler.cmake"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeCCompiler.cmake"[m
[32m+[m[32m  "CMakeFiles/3.15.5/CMakeCXXCompiler.cmake"[m
[32m+[m[32m  "CMakeFiles/CMakeDirectoryInformation.cmake"[m
[32m+[m[32m  )[m
[32m+[m
[32m+[m[32m# Dependency information for all targets:[m
[32m+[m[32mset(CMAKE_DEPEND_INFO_FILES[m
[32m+[m[32m  "CMakeFiles/Project-mm.dir/DependInfo.cmake"[m
[32m+[m[32m  )[m
[1mdiff --git a/kernel/mm/CMakeFiles/Makefile2 b/kernel/mm/CMakeFiles/Makefile2[m
[1mnew file mode 100644[m
[1mindex 0000000..cb5504f[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Makefile2[m
[36m@@ -0,0 +1,111 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32m# Default target executed when no arguments are given to make.[m
[32m+[m[32mdefault_target: all[m
[32m+[m
[32m+[m[32m.PHONY : default_target[m
[32m+[m
[32m+[m[32m# The main recursive all target[m
[32m+[m[32mall:[m
[32m+[m
[32m+[m[32m.PHONY : all[m
[32m+[m
[32m+[m[32m# The main recursive preinstall target[m
[32m+[m[32mpreinstall:[m
[32m+[m
[32m+[m[32m.PHONY : preinstall[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Special targets provided by cmake.[m
[32m+[m
[32m+[m[32m# Disable implicit rules so canonical targets will work.[m
[32m+[m[32m.SUFFIXES:[m
[32m+[m
[32m+[m
[32m+[m[32m# Remove some rules from gmake that .SUFFIXES does not remove.[m
[32m+[m[32mSUFFIXES =[m
[32m+[m
[32m+[m[32m.SUFFIXES: .hpux_make_needs_suffix_list[m
[32m+[m
[32m+[m
[32m+[m[32m# Suppress display of executed commands.[m
[32m+[m[32m$(VERBOSE).SILENT:[m
[32m+[m
[32m+[m
[32m+[m[32m# A target that is always out of date.[m
[32m+[m[32mcmake_force:[m
[32m+[m
[32m+[m[32m.PHONY : cmake_force[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Set environment variables for the build.[m
[32m+[m
[32m+[m[32m# The shell in which to execute make rules.[m
[32m+[m[32mSHELL = /bin/sh[m
[32m+[m
[32m+[m[32m# The CMake executable.[m
[32m+[m[32mCMAKE_COMMAND = /usr/local/bin/cmake[m
[32m+[m
[32m+[m[32m# The command to remove a file.[m
[32m+[m[32mRM = /usr/local/bin/cmake -E remove -f[m
[32m+[m
[32m+[m[32m# Escaping for special characters.[m
[32m+[m[32mEQUALS = =[m
[32m+[m
[32m+[m[32m# The top-level source directory on which CMake was run.[m
[32m+[m[32mCMAKE_SOURCE_DIR = /chos/kernel/mm[m
[32m+[m
[32m+[m[32m# The top-level build directory on which CMake was run.[m
[32m+[m[32mCMAKE_BINARY_DIR = /chos/kernel/mm[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Directory level rules for the build root directory[m
[32m+[m
[32m+[m[32m# The main recursive "clean" target.[m
[32m+[m[32mclean: CMakeFiles/Project-mm.dir/clean[m
[32m+[m
[32m+[m[32m.PHONY : clean[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Target rules for target CMakeFiles/Project-mm.dir[m
[32m+[m
[32m+[m[32m# All Build rule for target.[m
[32m+[m[32mCMakeFiles/Project-mm.dir/all:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/depend[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/build[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --progress-dir=/chos/kernel/mm/CMakeFiles --progress-num=1,2,3,4,5 "Built target Project-mm"[m
[32m+[m[32m.PHONY : CMakeFiles/Project-mm.dir/all[m
[32m+[m
[32m+[m[32m# Include target in all.[m
[32m+[m[32mall: CMakeFiles/Project-mm.dir/all[m
[32m+[m
[32m+[m[32m.PHONY : all[m
[32m+[m
[32m+[m[32m# Build rule for subdir invocation for target.[m
[32m+[m[32mCMakeFiles/Project-mm.dir/rule: cmake_check_build_system[m
[32m+[m	[32m$(CMAKE_COMMAND) -E cmake_progress_start /chos/kernel/mm/CMakeFiles 5[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Makefile2 CMakeFiles/Project-mm.dir/all[m
[32m+[m	[32m$(CMAKE_COMMAND) -E cmake_progress_start /chos/kernel/mm/CMakeFiles 0[m
[32m+[m[32m.PHONY : CMakeFiles/Project-mm.dir/rule[m
[32m+[m
[32m+[m[32m# Convenience name for target.[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/rule[m
[32m+[m
[32m+[m[32m.PHONY : Project-mm[m
[32m+[m
[32m+[m[32m# clean rule for target.[m
[32m+[m[32mCMakeFiles/Project-mm.dir/clean:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/clean[m
[32m+[m[32m.PHONY : CMakeFiles/Project-mm.dir/clean[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Special targets to cleanup operation of make.[m
[32m+[m
[32m+[m[32m# Special rule to run CMake to check the build system integrity.[m
[32m+[m[32m# No rule that depends on this can have commands that come from listfiles[m
[32m+[m[32m# because they might be regenerated.[m
[32m+[m[32mcmake_check_build_system:[m
[32m+[m	[32m$(CMAKE_COMMAND) -S$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR) --check-build-system CMakeFiles/Makefile.cmake 0[m
[32m+[m[32m.PHONY : cmake_check_build_system[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/Progress/1 b/kernel/mm/CMakeFiles/Progress/1[m
[1mnew file mode 100644[m
[1mindex 0000000..7b4d68d[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Progress/1[m
[36m@@ -0,0 +1 @@[m
[32m+[m[32mempty[m
\ No newline at end of file[m
[1mdiff --git a/kernel/mm/CMakeFiles/Progress/count.txt b/kernel/mm/CMakeFiles/Progress/count.txt[m
[1mnew file mode 100644[m
[1mindex 0000000..7ed6ff8[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Progress/count.txt[m
[36m@@ -0,0 +1 @@[m
[32m+[m[32m5[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/C.includecache b/kernel/mm/CMakeFiles/Project-mm.dir/C.includecache[m
[1mnew file mode 100644[m
[1mindex 0000000..bcf364d[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/C.includecache[m
[36m@@ -0,0 +1,92 @@[m
[32m+[m[32m#IncludeRegexLine: ^[ 	]*[#%][ 	]*(include|import)[ 	]*[<"]([^">]+)([">])[m
[32m+[m
[32m+[m[32m#IncludeRegexScan: ^.*$[m
[32m+[m
[32m+[m[32m#IncludeRegexComplain: ^$[m
[32m+[m
[32m+[m[32m#IncludeRegexTransform:[m[41m [m
[32m+[m
[32m+[m[32m/chos/kernel/mm/buddy.c[m
[32m+[m[32mcommon/util.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/macro.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/kprint.h[m
[32m+[m[32m-[m
[32m+[m[32mbuddy.h[m
[32m+[m[32m/chos/kernel/mm/buddy.h[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/buddy.h[m
[32m+[m[32mcommon/types.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/list.h[m
[32m+[m[32m-[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/kmalloc.c[m
[32m+[m[32mcommon/types.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/macro.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/util.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/errno.h[m
[32m+[m[32m-[m
[32m+[m[32mslab.h[m
[32m+[m[32m/chos/kernel/mm/slab.h[m
[32m+[m[32mbuddy.h[m
[32m+[m[32m/chos/kernel/mm/buddy.h[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/mm.c[m
[32m+[m[32mcommon/mm.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/kprint.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/macro.h[m
[32m+[m[32m-[m
[32m+[m[32mbuddy.h[m
[32m+[m[32m/chos/kernel/mm/buddy.h[m
[32m+[m[32mslab.h[m
[32m+[m[32m/chos/kernel/mm/slab.h[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/page_table.c[m
[32m+[m[32mcommon/util.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/kmalloc.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/vars.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/macro.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/types.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/printk.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/mm.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/mmu.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/errno.h[m
[32m+[m[32m-[m
[32m+[m[32mpage_table.h[m
[32m+[m[32m/chos/kernel/mm/page_table.h[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/page_table.h[m
[32m+[m[32mcommon/types.h[m
[32m+[m[32m-[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/slab.c[m
[32m+[m[32mcommon/macro.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/types.h[m
[32m+[m[32m-[m
[32m+[m[32mcommon/kprint.h[m
[32m+[m[32m-[m
[32m+[m[32mslab.h[m
[32m+[m[32m/chos/kernel/mm/slab.h[m
[32m+[m[32mbuddy.h[m
[32m+[m[32m/chos/kernel/mm/buddy.h[m
[32m+[m
[32m+[m[32m/chos/kernel/mm/slab.h[m
[32m+[m[32mcommon/types.h[m
[32m+[m[32m-[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/DependInfo.cmake b/kernel/mm/CMakeFiles/Project-mm.dir/DependInfo.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..be0a88c[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/DependInfo.cmake[m
[36m@@ -0,0 +1,25 @@[m
[32m+[m[32m# The set of languages for which implicit dependencies are needed:[m
[32m+[m[32mset(CMAKE_DEPENDS_LANGUAGES[m
[32m+[m[32m  "C"[m
[32m+[m[32m  )[m
[32m+[m[32m# The set of files for implicit dependencies of each language:[m
[32m+[m[32mset(CMAKE_DEPENDS_CHECK_C[m
[32m+[m[32m  "/chos/kernel/mm/buddy.c" "/chos/kernel/mm/CMakeFiles/Project-mm.dir/buddy.c.o"[m
[32m+[m[32m  "/chos/kernel/mm/kmalloc.c" "/chos/kernel/mm/CMakeFiles/Project-mm.dir/kmalloc.c.o"[m
[32m+[m[32m  "/chos/kernel/mm/mm.c" "/chos/kernel/mm/CMakeFiles/Project-mm.dir/mm.c.o"[m
[32m+[m[32m  "/chos/kernel/mm/page_table.c" "/chos/kernel/mm/CMakeFiles/Project-mm.dir/page_table.c.o"[m
[32m+[m[32m  "/chos/kernel/mm/slab.c" "/chos/kernel/mm/CMakeFiles/Project-mm.dir/slab.c.o"[m
[32m+[m[32m  )[m
[32m+[m[32mset(CMAKE_C_COMPILER_ID "GNU")[m
[32m+[m
[32m+[m[32m# The include file search paths:[m
[32m+[m[32mset(CMAKE_C_TARGET_INCLUDE_PATH[m
[32m+[m[32m  "include"[m
[32m+[m[32m  )[m
[32m+[m
[32m+[m[32m# Targets to which this target links.[m
[32m+[m[32mset(CMAKE_TARGET_LINKED_INFO_FILES[m
[32m+[m[32m  )[m
[32m+[m
[32m+[m[32m# Fortran module output directory.[m
[32m+[m[32mset(CMAKE_Fortran_TARGET_MODULE_DIR "")[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/build.make b/kernel/mm/CMakeFiles/Project-mm.dir/build.make[m
[1mnew file mode 100644[m
[1mindex 0000000..26dcf5f[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/build.make[m
[36m@@ -0,0 +1,146 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32m# Delete rule output on recipe failure.[m
[32m+[m[32m.DELETE_ON_ERROR:[m
[32m+[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Special targets provided by cmake.[m
[32m+[m
[32m+[m[32m# Disable implicit rules so canonical targets will work.[m
[32m+[m[32m.SUFFIXES:[m
[32m+[m
[32m+[m
[32m+[m[32m# Remove some rules from gmake that .SUFFIXES does not remove.[m
[32m+[m[32mSUFFIXES =[m
[32m+[m
[32m+[m[32m.SUFFIXES: .hpux_make_needs_suffix_list[m
[32m+[m
[32m+[m
[32m+[m[32m# Suppress display of executed commands.[m
[32m+[m[32m$(VERBOSE).SILENT:[m
[32m+[m
[32m+[m
[32m+[m[32m# A target that is always out of date.[m
[32m+[m[32mcmake_force:[m
[32m+[m
[32m+[m[32m.PHONY : cmake_force[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Set environment variables for the build.[m
[32m+[m
[32m+[m[32m# The shell in which to execute make rules.[m
[32m+[m[32mSHELL = /bin/sh[m
[32m+[m
[32m+[m[32m# The CMake executable.[m
[32m+[m[32mCMAKE_COMMAND = /usr/local/bin/cmake[m
[32m+[m
[32m+[m[32m# The command to remove a file.[m
[32m+[m[32mRM = /usr/local/bin/cmake -E remove -f[m
[32m+[m
[32m+[m[32m# Escaping for special characters.[m
[32m+[m[32mEQUALS = =[m
[32m+[m
[32m+[m[32m# The top-level source directory on which CMake was run.[m
[32m+[m[32mCMAKE_SOURCE_DIR = /chos/kernel/mm[m
[32m+[m
[32m+[m[32m# The top-level build directory on which CMake was run.[m
[32m+[m[32mCMAKE_BINARY_DIR = /chos/kernel/mm[m
[32m+[m
[32m+[m[32m# Include any dependencies generated for this target.[m
[32m+[m[32minclude CMakeFiles/Project-mm.dir/depend.make[m
[32m+[m
[32m+[m[32m# Include the progress variables for this target.[m
[32m+[m[32minclude CMakeFiles/Project-mm.dir/progress.make[m
[32m+[m
[32m+[m[32m# Include the compile flags for this target's objects.[m
[32m+[m[32minclude CMakeFiles/Project-mm.dir/flags.make[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.o: CMakeFiles/Project-mm.dir/flags.make[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.o: buddy.c[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/chos/kernel/mm/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building C object CMakeFiles/Project-mm.dir/buddy.c.o"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/Project-mm.dir/buddy.c.o   -c /chos/kernel/mm/buddy.c[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.i: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/Project-mm.dir/buddy.c.i"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /chos/kernel/mm/buddy.c > CMakeFiles/Project-mm.dir/buddy.c.i[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.s: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/Project-mm.dir/buddy.c.s"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /chos/kernel/mm/buddy.c -o CMakeFiles/Project-mm.dir/buddy.c.s[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.o: CMakeFiles/Project-mm.dir/flags.make[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.o: kmalloc.c[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/chos/kernel/mm/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Building C object CMakeFiles/Project-mm.dir/kmalloc.c.o"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/Project-mm.dir/kmalloc.c.o   -c /chos/kernel/mm/kmalloc.c[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.i: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/Project-mm.dir/kmalloc.c.i"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /chos/kernel/mm/kmalloc.c > CMakeFiles/Project-mm.dir/kmalloc.c.i[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.s: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/Project-mm.dir/kmalloc.c.s"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /chos/kernel/mm/kmalloc.c -o CMakeFiles/Project-mm.dir/kmalloc.c.s[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.o: CMakeFiles/Project-mm.dir/flags.make[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.o: mm.c[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/chos/kernel/mm/CMakeFiles --progress-num=$(CMAKE_PROGRESS_3) "Building C object CMakeFiles/Project-mm.dir/mm.c.o"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/Project-mm.dir/mm.c.o   -c /chos/kernel/mm/mm.c[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.i: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/Project-mm.dir/mm.c.i"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /chos/kernel/mm/mm.c > CMakeFiles/Project-mm.dir/mm.c.i[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.s: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/Project-mm.dir/mm.c.s"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /chos/kernel/mm/mm.c -o CMakeFiles/Project-mm.dir/mm.c.s[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.o: CMakeFiles/Project-mm.dir/flags.make[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.o: page_table.c[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/chos/kernel/mm/CMakeFiles --progress-num=$(CMAKE_PROGRESS_4) "Building C object CMakeFiles/Project-mm.dir/page_table.c.o"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/Project-mm.dir/page_table.c.o   -c /chos/kernel/mm/page_table.c[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.i: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/Project-mm.dir/page_table.c.i"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /chos/kernel/mm/page_table.c > CMakeFiles/Project-mm.dir/page_table.c.i[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.s: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/Project-mm.dir/page_table.c.s"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /chos/kernel/mm/page_table.c -o CMakeFiles/Project-mm.dir/page_table.c.s[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.o: CMakeFiles/Project-mm.dir/flags.make[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.o: slab.c[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/chos/kernel/mm/CMakeFiles --progress-num=$(CMAKE_PROGRESS_5) "Building C object CMakeFiles/Project-mm.dir/slab.c.o"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/Project-mm.dir/slab.c.o   -c /chos/kernel/mm/slab.c[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.i: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/Project-mm.dir/slab.c.i"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /chos/kernel/mm/slab.c > CMakeFiles/Project-mm.dir/slab.c.i[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.s: cmake_force[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/Project-mm.dir/slab.c.s"[m
[32m+[m	[32m/usr/bin/cc $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /chos/kernel/mm/slab.c -o CMakeFiles/Project-mm.dir/slab.c.s[m
[32m+[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/buddy.c.o[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/kmalloc.c.o[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/mm.c.o[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/page_table.c.o[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/slab.c.o[m
[32m+[m[32mProject-mm: CMakeFiles/Project-mm.dir/build.make[m
[32m+[m
[32m+[m[32m.PHONY : Project-mm[m
[32m+[m
[32m+[m[32m# Rule to build all files generated by this target.[m
[32m+[m[32mCMakeFiles/Project-mm.dir/build: Project-mm[m
[32m+[m
[32m+[m[32m.PHONY : CMakeFiles/Project-mm.dir/build[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/clean:[m
[32m+[m	[32m$(CMAKE_COMMAND) -P CMakeFiles/Project-mm.dir/cmake_clean.cmake[m
[32m+[m[32m.PHONY : CMakeFiles/Project-mm.dir/clean[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/depend:[m
[32m+[m	[32mcd /chos/kernel/mm && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /chos/kernel/mm /chos/kernel/mm /chos/kernel/mm /chos/kernel/mm /chos/kernel/mm/CMakeFiles/Project-mm.dir/DependInfo.cmake --color=$(COLOR)[m
[32m+[m[32m.PHONY : CMakeFiles/Project-mm.dir/depend[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/cmake_clean.cmake b/kernel/mm/CMakeFiles/Project-mm.dir/cmake_clean.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..4ca6616[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/cmake_clean.cmake[m
[36m@@ -0,0 +1,12 @@[m
[32m+[m[32mfile(REMOVE_RECURSE[m
[32m+[m[32m  "CMakeFiles/Project-mm.dir/buddy.c.o"[m
[32m+[m[32m  "CMakeFiles/Project-mm.dir/kmalloc.c.o"[m
[32m+[m[32m  "CMakeFiles/Project-mm.dir/mm.c.o"[m
[32m+[m[32m  "CMakeFiles/Project-mm.dir/page_table.c.o"[m
[32m+[m[32m  "CMakeFiles/Project-mm.dir/slab.c.o"[m
[32m+[m[32m)[m
[32m+[m
[32m+[m[32m# Per-language clean rules from dependency scanning.[m
[32m+[m[32mforeach(lang C)[m
[32m+[m[32m  include(CMakeFiles/Project-mm.dir/cmake_clean_${lang}.cmake OPTIONAL)[m
[32m+[m[32mendforeach()[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/depend.internal b/kernel/mm/CMakeFiles/Project-mm.dir/depend.internal[m
[1mnew file mode 100644[m
[1mindex 0000000..22384b8[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/depend.internal[m
[36m@@ -0,0 +1,21 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.o[m
[32m+[m[32m /chos/kernel/mm/buddy.c[m
[32m+[m[32m /chos/kernel/mm/buddy.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.o[m
[32m+[m[32m /chos/kernel/mm/buddy.h[m
[32m+[m[32m /chos/kernel/mm/kmalloc.c[m
[32m+[m[32m /chos/kernel/mm/slab.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.o[m
[32m+[m[32m /chos/kernel/mm/buddy.h[m
[32m+[m[32m /chos/kernel/mm/mm.c[m
[32m+[m[32m /chos/kernel/mm/slab.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.o[m
[32m+[m[32m /chos/kernel/mm/page_table.c[m
[32m+[m[32m /chos/kernel/mm/page_table.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.o[m
[32m+[m[32m /chos/kernel/mm/buddy.h[m
[32m+[m[32m /chos/kernel/mm/slab.c[m
[32m+[m[32m /chos/kernel/mm/slab.h[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/depend.make b/kernel/mm/CMakeFiles/Project-mm.dir/depend.make[m
[1mnew file mode 100644[m
[1mindex 0000000..6742745[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/depend.make[m
[36m@@ -0,0 +1,21 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.o: buddy.c[m
[32m+[m[32mCMakeFiles/Project-mm.dir/buddy.c.o: buddy.h[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.o: buddy.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.o: kmalloc.c[m
[32m+[m[32mCMakeFiles/Project-mm.dir/kmalloc.c.o: slab.h[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.o: buddy.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.o: mm.c[m
[32m+[m[32mCMakeFiles/Project-mm.dir/mm.c.o: slab.h[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.o: page_table.c[m
[32m+[m[32mCMakeFiles/Project-mm.dir/page_table.c.o: page_table.h[m
[32m+[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.o: buddy.h[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.o: slab.c[m
[32m+[m[32mCMakeFiles/Project-mm.dir/slab.c.o: slab.h[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/flags.make b/kernel/mm/CMakeFiles/Project-mm.dir/flags.make[m
[1mnew file mode 100644[m
[1mindex 0000000..84630ba[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/flags.make[m
[36m@@ -0,0 +1,10 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32m# compile C with /usr/bin/cc[m
[32m+[m[32mC_FLAGS =[m[41m  [m
[32m+[m
[32m+[m[32mC_DEFINES =[m[41m [m
[32m+[m
[32m+[m[32mC_INCLUDES = -I/chos/kernel/mm/include[m[41m [m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/Project-mm.dir/progress.make b/kernel/mm/CMakeFiles/Project-mm.dir/progress.make[m
[1mnew file mode 100644[m
[1mindex 0000000..33e6bff[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/Project-mm.dir/progress.make[m
[36m@@ -0,0 +1,6 @@[m
[32m+[m[32mCMAKE_PROGRESS_1 = 1[m
[32m+[m[32mCMAKE_PROGRESS_2 = 2[m
[32m+[m[32mCMAKE_PROGRESS_3 = 3[m
[32m+[m[32mCMAKE_PROGRESS_4 = 4[m
[32m+[m[32mCMAKE_PROGRESS_5 = 5[m
[32m+[m
[1mdiff --git a/kernel/mm/CMakeFiles/TargetDirectories.txt b/kernel/mm/CMakeFiles/TargetDirectories.txt[m
[1mnew file mode 100644[m
[1mindex 0000000..e770fa6[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/TargetDirectories.txt[m
[36m@@ -0,0 +1,3 @@[m
[32m+[m[32m/chos/kernel/mm/CMakeFiles/rebuild_cache.dir[m
[32m+[m[32m/chos/kernel/mm/CMakeFiles/Project-mm.dir[m
[32m+[m[32m/chos/kernel/mm/CMakeFiles/edit_cache.dir[m
[1mdiff --git a/kernel/mm/CMakeFiles/cmake.check_cache b/kernel/mm/CMakeFiles/cmake.check_cache[m
[1mnew file mode 100644[m
[1mindex 0000000..3dccd73[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/cmake.check_cache[m
[36m@@ -0,0 +1 @@[m
[32m+[m[32m# This file is generated by cmake for dependency checking of the CMakeCache.txt file[m
[1mdiff --git a/kernel/mm/CMakeFiles/progress.marks b/kernel/mm/CMakeFiles/progress.marks[m
[1mnew file mode 100644[m
[1mindex 0000000..7ed6ff8[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/CMakeFiles/progress.marks[m
[36m@@ -0,0 +1 @@[m
[32m+[m[32m5[m
[1mdiff --git a/kernel/mm/Makefile b/kernel/mm/Makefile[m
[1mnew file mode 100644[m
[1mindex 0000000..c06c419[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/Makefile[m
[36m@@ -0,0 +1,298 @@[m
[32m+[m[32m# CMAKE generated file: DO NOT EDIT![m
[32m+[m[32m# Generated by "Unix Makefiles" Generator, CMake Version 3.15[m
[32m+[m
[32m+[m[32m# Default target executed when no arguments are given to make.[m
[32m+[m[32mdefault_target: all[m
[32m+[m
[32m+[m[32m.PHONY : default_target[m
[32m+[m
[32m+[m[32m# Allow only one "make -f Makefile2" at a time, but pass parallelism.[m
[32m+[m[32m.NOTPARALLEL:[m
[32m+[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Special targets provided by cmake.[m
[32m+[m
[32m+[m[32m# Disable implicit rules so canonical targets will work.[m
[32m+[m[32m.SUFFIXES:[m
[32m+[m
[32m+[m
[32m+[m[32m# Remove some rules from gmake that .SUFFIXES does not remove.[m
[32m+[m[32mSUFFIXES =[m
[32m+[m
[32m+[m[32m.SUFFIXES: .hpux_make_needs_suffix_list[m
[32m+[m
[32m+[m
[32m+[m[32m# Suppress display of executed commands.[m
[32m+[m[32m$(VERBOSE).SILENT:[m
[32m+[m
[32m+[m
[32m+[m[32m# A target that is always out of date.[m
[32m+[m[32mcmake_force:[m
[32m+[m
[32m+[m[32m.PHONY : cmake_force[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Set environment variables for the build.[m
[32m+[m
[32m+[m[32m# The shell in which to execute make rules.[m
[32m+[m[32mSHELL = /bin/sh[m
[32m+[m
[32m+[m[32m# The CMake executable.[m
[32m+[m[32mCMAKE_COMMAND = /usr/local/bin/cmake[m
[32m+[m
[32m+[m[32m# The command to remove a file.[m
[32m+[m[32mRM = /usr/local/bin/cmake -E remove -f[m
[32m+[m
[32m+[m[32m# Escaping for special characters.[m
[32m+[m[32mEQUALS = =[m
[32m+[m
[32m+[m[32m# The top-level source directory on which CMake was run.[m
[32m+[m[32mCMAKE_SOURCE_DIR = /chos/kernel/mm[m
[32m+[m
[32m+[m[32m# The top-level build directory on which CMake was run.[m
[32m+[m[32mCMAKE_BINARY_DIR = /chos/kernel/mm[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Targets provided globally by CMake.[m
[32m+[m
[32m+[m[32m# Special rule for the target rebuild_cache[m
[32m+[m[32mrebuild_cache:[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Running CMake to regenerate build system..."[m
[32m+[m	[32m/usr/local/bin/cmake -S$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR)[m
[32m+[m[32m.PHONY : rebuild_cache[m
[32m+[m
[32m+[m[32m# Special rule for the target rebuild_cache[m
[32m+[m[32mrebuild_cache/fast: rebuild_cache[m
[32m+[m
[32m+[m[32m.PHONY : rebuild_cache/fast[m
[32m+[m
[32m+[m[32m# Special rule for the target edit_cache[m
[32m+[m[32medit_cache:[m
[32m+[m	[32m@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "No interactive CMake dialog available..."[m
[32m+[m	[32m/usr/local/bin/cmake -E echo No\ interactive\ CMake\ dialog\ available.[m
[32m+[m[32m.PHONY : edit_cache[m
[32m+[m
[32m+[m[32m# Special rule for the target edit_cache[m
[32m+[m[32medit_cache/fast: edit_cache[m
[32m+[m
[32m+[m[32m.PHONY : edit_cache/fast[m
[32m+[m
[32m+[m[32m# The main all target[m
[32m+[m[32mall: cmake_check_build_system[m
[32m+[m	[32m$(CMAKE_COMMAND) -E cmake_progress_start /chos/kernel/mm/CMakeFiles /chos/kernel/mm/CMakeFiles/progress.marks[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Makefile2 all[m
[32m+[m	[32m$(CMAKE_COMMAND) -E cmake_progress_start /chos/kernel/mm/CMakeFiles 0[m
[32m+[m[32m.PHONY : all[m
[32m+[m
[32m+[m[32m# The main clean target[m
[32m+[m[32mclean:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Makefile2 clean[m
[32m+[m[32m.PHONY : clean[m
[32m+[m
[32m+[m[32m# The main clean target[m
[32m+[m[32mclean/fast: clean[m
[32m+[m
[32m+[m[32m.PHONY : clean/fast[m
[32m+[m
[32m+[m[32m# Prepare targets for installation.[m
[32m+[m[32mpreinstall: all[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Makefile2 preinstall[m
[32m+[m[32m.PHONY : preinstall[m
[32m+[m
[32m+[m[32m# Prepare targets for installation.[m
[32m+[m[32mpreinstall/fast:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Makefile2 preinstall[m
[32m+[m[32m.PHONY : preinstall/fast[m
[32m+[m
[32m+[m[32m# clear depends[m
[32m+[m[32mdepend:[m
[32m+[m	[32m$(CMAKE_COMMAND) -S$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR) --check-build-system CMakeFiles/Makefile.cmake 1[m
[32m+[m[32m.PHONY : depend[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Target rules for targets named Project-mm[m
[32m+[m
[32m+[m[32m# Build rule for target.[m
[32m+[m[32mProject-mm: cmake_check_build_system[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Makefile2 Project-mm[m
[32m+[m[32m.PHONY : Project-mm[m
[32m+[m
[32m+[m[32m# fast build rule for target.[m
[32m+[m[32mProject-mm/fast:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/build[m
[32m+[m[32m.PHONY : Project-mm/fast[m
[32m+[m
[32m+[m[32mbuddy.o: buddy.c.o[m
[32m+[m
[32m+[m[32m.PHONY : buddy.o[m
[32m+[m
[32m+[m[32m# target to build an object file[m
[32m+[m[32mbuddy.c.o:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/buddy.c.o[m
[32m+[m[32m.PHONY : buddy.c.o[m
[32m+[m
[32m+[m[32mbuddy.i: buddy.c.i[m
[32m+[m
[32m+[m[32m.PHONY : buddy.i[m
[32m+[m
[32m+[m[32m# target to preprocess a source file[m
[32m+[m[32mbuddy.c.i:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/buddy.c.i[m
[32m+[m[32m.PHONY : buddy.c.i[m
[32m+[m
[32m+[m[32mbuddy.s: buddy.c.s[m
[32m+[m
[32m+[m[32m.PHONY : buddy.s[m
[32m+[m
[32m+[m[32m# target to generate assembly for a file[m
[32m+[m[32mbuddy.c.s:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/buddy.c.s[m
[32m+[m[32m.PHONY : buddy.c.s[m
[32m+[m
[32m+[m[32mkmalloc.o: kmalloc.c.o[m
[32m+[m
[32m+[m[32m.PHONY : kmalloc.o[m
[32m+[m
[32m+[m[32m# target to build an object file[m
[32m+[m[32mkmalloc.c.o:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/kmalloc.c.o[m
[32m+[m[32m.PHONY : kmalloc.c.o[m
[32m+[m
[32m+[m[32mkmalloc.i: kmalloc.c.i[m
[32m+[m
[32m+[m[32m.PHONY : kmalloc.i[m
[32m+[m
[32m+[m[32m# target to preprocess a source file[m
[32m+[m[32mkmalloc.c.i:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/kmalloc.c.i[m
[32m+[m[32m.PHONY : kmalloc.c.i[m
[32m+[m
[32m+[m[32mkmalloc.s: kmalloc.c.s[m
[32m+[m
[32m+[m[32m.PHONY : kmalloc.s[m
[32m+[m
[32m+[m[32m# target to generate assembly for a file[m
[32m+[m[32mkmalloc.c.s:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/kmalloc.c.s[m
[32m+[m[32m.PHONY : kmalloc.c.s[m
[32m+[m
[32m+[m[32mmm.o: mm.c.o[m
[32m+[m
[32m+[m[32m.PHONY : mm.o[m
[32m+[m
[32m+[m[32m# target to build an object file[m
[32m+[m[32mmm.c.o:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/mm.c.o[m
[32m+[m[32m.PHONY : mm.c.o[m
[32m+[m
[32m+[m[32mmm.i: mm.c.i[m
[32m+[m
[32m+[m[32m.PHONY : mm.i[m
[32m+[m
[32m+[m[32m# target to preprocess a source file[m
[32m+[m[32mmm.c.i:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/mm.c.i[m
[32m+[m[32m.PHONY : mm.c.i[m
[32m+[m
[32m+[m[32mmm.s: mm.c.s[m
[32m+[m
[32m+[m[32m.PHONY : mm.s[m
[32m+[m
[32m+[m[32m# target to generate assembly for a file[m
[32m+[m[32mmm.c.s:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/mm.c.s[m
[32m+[m[32m.PHONY : mm.c.s[m
[32m+[m
[32m+[m[32mpage_table.o: page_table.c.o[m
[32m+[m
[32m+[m[32m.PHONY : page_table.o[m
[32m+[m
[32m+[m[32m# target to build an object file[m
[32m+[m[32mpage_table.c.o:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/page_table.c.o[m
[32m+[m[32m.PHONY : page_table.c.o[m
[32m+[m
[32m+[m[32mpage_table.i: page_table.c.i[m
[32m+[m
[32m+[m[32m.PHONY : page_table.i[m
[32m+[m
[32m+[m[32m# target to preprocess a source file[m
[32m+[m[32mpage_table.c.i:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/page_table.c.i[m
[32m+[m[32m.PHONY : page_table.c.i[m
[32m+[m
[32m+[m[32mpage_table.s: page_table.c.s[m
[32m+[m
[32m+[m[32m.PHONY : page_table.s[m
[32m+[m
[32m+[m[32m# target to generate assembly for a file[m
[32m+[m[32mpage_table.c.s:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/page_table.c.s[m
[32m+[m[32m.PHONY : page_table.c.s[m
[32m+[m
[32m+[m[32mslab.o: slab.c.o[m
[32m+[m
[32m+[m[32m.PHONY : slab.o[m
[32m+[m
[32m+[m[32m# target to build an object file[m
[32m+[m[32mslab.c.o:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/slab.c.o[m
[32m+[m[32m.PHONY : slab.c.o[m
[32m+[m
[32m+[m[32mslab.i: slab.c.i[m
[32m+[m
[32m+[m[32m.PHONY : slab.i[m
[32m+[m
[32m+[m[32m# target to preprocess a source file[m
[32m+[m[32mslab.c.i:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/slab.c.i[m
[32m+[m[32m.PHONY : slab.c.i[m
[32m+[m
[32m+[m[32mslab.s: slab.c.s[m
[32m+[m
[32m+[m[32m.PHONY : slab.s[m
[32m+[m
[32m+[m[32m# target to generate assembly for a file[m
[32m+[m[32mslab.c.s:[m
[32m+[m	[32m$(MAKE) -f CMakeFiles/Project-mm.dir/build.make CMakeFiles/Project-mm.dir/slab.c.s[m
[32m+[m[32m.PHONY : slab.c.s[m
[32m+[m
[32m+[m[32m# Help Target[m
[32m+[m[32mhelp:[m
[32m+[m	[32m@echo "The following are some of the valid targets for this Makefile:"[m
[32m+[m	[32m@echo "... all (the default if no target is provided)"[m
[32m+[m	[32m@echo "... clean"[m
[32m+[m	[32m@echo "... depend"[m
[32m+[m	[32m@echo "... rebuild_cache"[m
[32m+[m	[32m@echo "... Project-mm"[m
[32m+[m	[32m@echo "... edit_cache"[m
[32m+[m	[32m@echo "... buddy.o"[m
[32m+[m	[32m@echo "... buddy.i"[m
[32m+[m	[32m@echo "... buddy.s"[m
[32m+[m	[32m@echo "... kmalloc.o"[m
[32m+[m	[32m@echo "... kmalloc.i"[m
[32m+[m	[32m@echo "... kmalloc.s"[m
[32m+[m	[32m@echo "... mm.o"[m
[32m+[m	[32m@echo "... mm.i"[m
[32m+[m	[32m@echo "... mm.s"[m
[32m+[m	[32m@echo "... page_table.o"[m
[32m+[m	[32m@echo "... page_table.i"[m
[32m+[m	[32m@echo "... page_table.s"[m
[32m+[m	[32m@echo "... slab.o"[m
[32m+[m	[32m@echo "... slab.i"[m
[32m+[m	[32m@echo "... slab.s"[m
[32m+[m[32m.PHONY : help[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32m#=============================================================================[m
[32m+[m[32m# Special targets to cleanup operation of make.[m
[32m+[m
[32m+[m[32m# Special rule to run CMake to check the build system integrity.[m
[32m+[m[32m# No rule that depends on this can have commands that come from listfiles[m
[32m+[m[32m# because they might be regenerated.[m
[32m+[m[32mcmake_check_build_system:[m
[32m+[m	[32m$(CMAKE_COMMAND) -S$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR) --check-build-system CMakeFiles/Makefile.cmake 0[m
[32m+[m[32m.PHONY : cmake_check_build_system[m
[32m+[m
[1mdiff --git a/kernel/mm/buddy.c b/kernel/mm/buddy.c[m
[1mindex 37bfd97..9da8c1c 100644[m
[1m--- a/kernel/mm/buddy.c[m
[1m+++ b/kernel/mm/buddy.c[m
[36m@@ -75,6 +75,12 @@[m [mstatic struct page *get_buddy_chunk(struct phys_mem_pool *pool,[m
 	return virt_to_page(pool, (void *)buddy_chunk_addr);[m
 }[m
 [m
[32m+[m[32mstatic void del_node(struct phys_mem_pool *pool, struct page *page){[m
[32m+[m	[32mstruct free_list* origin_order_free_list = &(pool->free_lists[page->order]);[m
[32m+[m	[32morigin_order_free_list->nr_free--;[m
[32m+[m	[32mlist_del(&page->node);[m
[32m+[m[32m}[m
[32m+[m
 /*[m
  * split_page: split the memory block into two smaller sub-block, whose order[m
  * is half of the origin page.[m
[36m@@ -90,8 +96,31 @@[m [mstatic struct page *split_page(struct phys_mem_pool *pool, u64 order,[m
 			       struct page *page)[m
 {[m
 	// <lab2>[m
[31m-	struct page *split_page = NULL;[m
[31m-	return split_page;[m
[32m+[m	[32mif(page->allocated == 1 || page->order == 0 || page->order <= order){[m
[32m+[m		[32mreturn page;[m
[32m+[m	[32m}[m
[32m+[m[41m	[m
[32m+[m	[32mif(page->order - order > 1){[m
[32m+[m		[32mpage = split_page(pool, order + 1, page);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mstruct free_list* origin_order_free_list = &(pool->free_lists[page->order]);[m
[32m+[m	[32mstruct free_list* split_order_free_list = &(pool->free_lists[page->order - 1]);[m
[32m+[m
[32m+[m	[32mpage->order--;[m
[32m+[m	[32morigin_order_free_list->nr_free--;[m
[32m+[m	[32mlist_del(&page->node);[m
[32m+[m
[32m+[m	[32mstruct page *buddy = get_buddy_chunk(pool, page);[m
[32m+[m	[32mbuddy->allocated = 0;[m
[32m+[m	[32mbuddy->order = page->order;[m
[32m+[m[41m	[m
[32m+[m	[32msplit_order_free_list->nr_free += 2;[m
[32m+[m	[32mlist_add(&page->node, &split_order_free_list->free_list);[m
[32m+[m	[32mlist_add(&buddy->node, &split_order_free_list->free_list);[m
[32m+[m[41m		[m
[32m+[m	[32mreturn page;[m
[32m+[m
 	// </lab2>[m
 }[m
 [m
[36m@@ -106,7 +135,36 @@[m [mstatic struct page *split_page(struct phys_mem_pool *pool, u64 order,[m
 struct page *buddy_get_pages(struct phys_mem_pool *pool, u64 order)[m
 {[m
 	// <lab2>[m
[32m+[m	[32mif(order >= BUDDY_MAX_ORDER){[m
[32m+[m		[32mreturn NULL;[m
[32m+[m	[32m}[m
 	struct page *page = NULL;[m
[32m+[m	[32mstruct free_list *this_order_free_list = &(pool->free_lists[order]);[m
[32m+[m	[32mif(this_order_free_list->nr_free == 0){ // need to split larger page chunk[m
[32m+[m		[32mu64 larger_order = order;[m
[32m+[m		[32mwhile(this_order_free_list->nr_free == 0){[m
[32m+[m			[32mlarger_order++;[m
[32m+[m			[32mif(larger_order >= BUDDY_MAX_ORDER){[m
[32m+[m				[32mreturn NULL;[m
[32m+[m			[32m}[m
[32m+[m			[32mthis_order_free_list = &(pool->free_lists[larger_order]);[m
[32m+[m		[32m}[m
[32m+[m		[32mstruct list_head *list_node = this_order_free_list->free_list.next;[m
[32m+[m		[32mstruct page *page_split = list_entry(list_node, struct page, node);[m
[32m+[m		[32mpage = split_page(pool, order, page_split);[m
[32m+[m
[32m+[m		[32mpage->allocated = 1;[m
[32m+[m		[32mstruct free_list *page_order_free_list = &(pool->free_lists[page->order]);[m
[32m+[m		[32mpage_order_free_list->nr_free--;[m
[32m+[m		[32mlist_del(list_node);[m
[32m+[m	[32m}else{ //just allocate with this order[m
[32m+[m		[32mstruct list_head *list_node = this_order_free_list->free_list.next; //skip list header, which should be retained[m
[32m+[m		[32mpage = list_entry(list_node, struct page, node);[m
[32m+[m		[32mpage->allocated = 1;[m
[32m+[m
[32m+[m		[32mthis_order_free_list->nr_free--;[m
[32m+[m		[32mlist_del(list_node);[m
[32m+[m	[32m}[m
 [m
 	return page;[m
 	// </lab2>[m
[36m@@ -124,9 +182,34 @@[m [mstruct page *buddy_get_pages(struct phys_mem_pool *pool, u64 order)[m
 static struct page *merge_page(struct phys_mem_pool *pool, struct page *page)[m
 {[m
 	// <lab2>[m
[32m+[m	[32mif(page->order >= BUDDY_MAX_ORDER-1 || page->allocated == 1){[m
[32m+[m		[32mreturn page;[m
[32m+[m	[32m}[m
[32m+[m	[32mstruct page *buddy = get_buddy_chunk(pool, page);[m
[32m+[m	[32mif(buddy == NULL || buddy->allocated == 1 || buddy->order != page->order){ //buddy not exists/allocated/splitted[m
[32m+[m		[32mreturn page; //terminate recursion[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mif((u64)page > (u64)buddy){ //let page to be the former chunk, buudy the latter[m
[32m+[m		[32mstruct page *tmp = page;[m
[32m+[m		[32mpage = buddy;[m
[32m+[m		[32mbuddy = tmp;[m
[32m+[m	[32m}[m
[32m+[m	[32mstruct free_list* origin_order_free_list = &(pool->free_lists[page->order]);[m
[32m+[m	[32mstruct free_list* merge_order_free_list = &(pool->free_lists[page->order+1]);[m
[32m+[m
[32m+[m	[32m//delete 2 nodes belonging to page and buddy[m
[32m+[m	[32morigin_order_free_list->nr_free -= 2;[m
[32m+[m	[32mlist_del(&page->node);[m
[32m+[m	[32mlist_del(&buddy->node);[m
[32m+[m
[32m+[m	[32m//merge, and add 1 node to free_list with (order+1)[m
[32m+[m	[32mpage->order++;[m
[32m+[m	[32mmerge_order_free_list->nr_free++;[m
[32m+[m	[32mlist_add(&page->node, &merge_order_free_list->free_list);[m
 [m
[31m-	struct page *merge_page = NULL;[m
[31m-	return merge_page;[m
[32m+[m	[32m//recursive merge buddy[m
[32m+[m	[32mreturn merge_page(pool, page);[m
 	// </lab2>[m
 }[m
 [m
[36m@@ -140,7 +223,12 @@[m [mstatic struct page *merge_page(struct phys_mem_pool *pool, struct page *page)[m
 void buddy_free_pages(struct phys_mem_pool *pool, struct page *page)[m
 {[m
 	// <lab2>[m
[32m+[m	[32mpage->allocated = 0;[m
[32m+[m	[32mstruct free_list* origin_order_free_list = &(pool->free_lists[page->order]);[m
[32m+[m	[32morigin_order_free_list->nr_free++;[m
[32m+[m	[32mlist_add(&page->node, &origin_order_free_list->free_list);[m
 [m
[32m+[m	[32mpage = merge_page(pool, page);[m
 	// </lab2>[m
 }[m
 [m
[1mdiff --git a/kernel/mm/cmake_install.cmake b/kernel/mm/cmake_install.cmake[m
[1mnew file mode 100644[m
[1mindex 0000000..8f57bce[m
[1m--- /dev/null[m
[1m+++ b/kernel/mm/cmake_install.cmake[m
[36m@@ -0,0 +1,49 @@[m
[32m+[m[32m# Install script for directory: /chos/kernel/mm[m
[32m+[m
[32m+[m[32m# Set the install prefix[m
[32m+[m[32mif(NOT DEFINED CMAKE_INSTALL_PREFIX)[m
[32m+[m[32m  set(CMAKE_INSTALL_PREFIX "/usr/local")[m
[32m+[m[32mendif()[m
[32m+[m[32mstring(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")[m
[32m+[m
[32m+[m[32m# Set the install configuration name.[m
[32m+[m[32mif(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)[m
[32m+[m[32m  if(BUILD_TYPE)[m
[32m+[m[32m    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""[m
[32m+[m[32m           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")[m
[32m+[m[32m  else()[m
[32m+[m[32m    set(CMAKE_INSTALL_CONFIG_NAME "")[m
[32m+[m[32m  endif()[m
[32m+[m[32m  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32m# Set the component getting installed.[m
[32m+[m[32mif(NOT CMAKE_INSTALL_COMPONENT)[m
[32m+[m[32m  if(COMPONENT)[m
[32m+[m[32m    message(STATUS "Install component: \"${COMPONENT}\"")[m
[32m+[m[32m    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")[m
[32m+[m[32m  else()[m
[32m+[m[32m    set(CMAKE_INSTALL_COMPONENT)[m
[32m+[m[32m  endif()[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32m# Install shared libraries without execute permission?[m
[32m+[m[32mif(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)[m
[32m+[m[32m  set(CMAKE_INSTALL_SO_NO_EXE "1")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32m# Is this installation the result of a crosscompile?[m
[32m+[m[32mif(NOT DEFINED CMAKE_CROSSCOMPILING)[m
[32m+[m[32m  set(CMAKE_CROSSCOMPILING "FALSE")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mif(CMAKE_INSTALL_COMPONENT)[m
[32m+[m[32m  set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")[m
[32m+[m[32melse()[m
[32m+[m[32m  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")[m
[32m+[m[32mendif()[m
[32m+[m
[32m+[m[32mstring(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT[m
[32m+[m[32m       "${CMAKE_INSTALL_MANIFEST_FILES}")[m
[32m+[m[32mfile(WRITE "/chos/kernel/mm/${CMAKE_INSTALL_MANIFEST}"[m
[32m+[m[32m     "${CMAKE_INSTALL_MANIFEST_CONTENT}")[m
[1mdiff --git a/kernel/mm/mm.c b/kernel/mm/mm.c[m
[1mindex 7b0feb2..dc5958f 100644[m
[1m--- a/kernel/mm/mm.c[m
[1m+++ b/kernel/mm/mm.c[m
[36m@@ -16,7 +16,9 @@[m
 [m
 #include "buddy.h"[m
 #include "slab.h"[m
[32m+[m[32m#include "page_table.h"[m
 [m
[32m+[m[32mextern int get_next_ptp(ptp_t * cur_ptp, u32 level, vaddr_t va, ptp_t ** next_ptp, pte_t ** pte, bool alloc);[m
 extern unsigned long *img_end;[m
 [m
 #define PHYSICAL_MEM_START (24*1024*1024)	//24M[m
[36m@@ -51,7 +53,56 @@[m [munsigned long get_ttbr1(void)[m
 void map_kernel_space(vaddr_t va, paddr_t pa, size_t len)[m
 {[m
 	// <lab2>[m
[31m-[m
[32m+[m	[32munsigned long pgtbl = get_ttbr1(); //phisical addr.[m
[32m+[m	[32msize_t block_num = ROUND_UP(len, BLOCK_SIZE) / BLOCK_SIZE;[m
[32m+[m	[32m// size_t block_num = len / BLOCK_SIZE;[m
[32m+[m
[32m+[m	[32mptp_t *ptp_0 = (ptp_t *)(pgtbl), *ptp_1, *ptp_2, *next_ptp;[m
[32m+[m	[32mpte_t *pte_0, *pte_1, *pte_2;[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mfor(size_t i = 0;i < block_num;i++, va += BLOCK_SIZE, pa += BLOCK_SIZE){[m
[32m+[m		[32m// kinfo("i: %lx\n", i);[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_0, 0, va, &ptp_1, &pte_0, true)) < 0){[m
[32m+[m			[32mreturn;[m
[32m+[m		[32m}[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_1, 1, va, &ptp_2, &pte_1, true)) < 0){[m
[32m+[m			[32mreturn;[m
[32m+[m		[32m}[m
[32m+[m		[32mret = get_next_ptp(ptp_2, 2, va, &next_ptp, &pte_2, true);[m
[32m+[m
[32m+[m		[32mpte_2->l2_block.is_valid = 1;[m
[32m+[m		[32mpte_2->l2_block.is_table = 0;[m
[32m+[m
[32m+[m		[32mpte_2->l2_block.attr_index = 4;[m
[32m+[m		[32mpte_2->l2_block.SH = 3;[m
[32m+[m		[32mpte_2->l2_block.AF = 1;[m
[32m+[m		[32mpte_2->l2_block.UXN = 1;[m
[32m+[m[41m		[m
[32m+[m		[32mpte_2->l2_block.pfn = pa >> BLOCK_SHIFT;[m
[32m+[m	[32m}[m
[32m+[m	[32m// #define IS_VALID (1UL << 0)[m
[32m+[m	[32m// #define UXN	       (0x1UL << 54)[m
[32m+[m	[32m// #define ACCESSED       (0x1UL << 10)[m
[32m+[m	[32m// #define INNER_SHARABLE (0x3UL << 8)[m
[32m+[m	[32m// #define NORMAL_MEMORY  (0x4UL << 2)[m
[32m+[m
[32m+[m	[32m// #define GET_L0_INDEX(x) (((x) >> (12 + 9 + 9 + 9)) & 0x1ff)[m
[32m+[m	[32m// #define GET_L1_INDEX(x) (((x) >> (12 + 9 + 9)) & 0x1ff)[m
[32m+[m	[32m// #define GET_L2_INDEX(x) (((x) >> (12 + 9)) & 0x1ff)[m
[32m+[m	[32m// u64 *pgd = get_ttbr1() + KBASE;[m
[32m+[m	[32m// len = ROUND_UP(len, (PAGE_SIZE << 9));[m
[32m+[m	[32m// for (size_t mapped = 0; mapped < len; mapped += (PAGE_SIZE << 9)) {[m
[32m+[m	[32m// 	u32 l0_idx = GET_L0_INDEX(va + mapped);[m
[32m+[m	[32m// 	u64 *l1_tbl = (pgd[l0_idx] & ~0xFF) + KBASE;[m
[32m+[m	[32m// 	u32 l1_idx = GET_L1_INDEX(va + mapped);[m
[32m+[m	[32m// 	u64 *l2_tbl = (l1_tbl[l1_idx] & ~0xFF) + KBASE;[m
[32m+[m	[32m// 	u32 l2_idx = GET_L2_INDEX(va + mapped);[m
[32m+[m	[32m// 	l2_tbl[l2_idx] = (pa + mapped) | UXN	/* Unprivileged execute never */[m
[32m+[m	[32m// 	    | ACCESSED	/* Set access flag */[m
[32m+[m	[32m// 	    | INNER_SHARABLE	/* Sharebility */[m
[32m+[m	[32m// 	    | NORMAL_MEMORY	/* Normal memory */[m
[32m+[m	[32m// 	    | IS_VALID;[m
[32m+[m	[32m// }[m
 	// </lab2>[m
 }[m
 [m
[1mdiff --git a/kernel/mm/page_table.c b/kernel/mm/page_table.c[m
[1mindex 0109d93..27db4a0 100644[m
[1m--- a/kernel/mm/page_table.c[m
[1m+++ b/kernel/mm/page_table.c[m
[36m@@ -84,7 +84,7 @@[m [mstatic int set_pte_flags(pte_t * entry, vmr_prop_t flags, int kind)[m
  * alloc: if true, allocate a ptp when missing[m
  *[m
  */[m
[31m-static int get_next_ptp(ptp_t * cur_ptp, u32 level, vaddr_t va,[m
[32m+[m[32mint get_next_ptp(ptp_t * cur_ptp, u32 level, vaddr_t va,[m
 			ptp_t ** next_ptp, pte_t ** pte, bool alloc)[m
 {[m
 	u32 index = 0;[m
[36m@@ -162,9 +162,85 @@[m [mstatic int get_next_ptp(ptp_t * cur_ptp, u32 level, vaddr_t va,[m
 int query_in_pgtbl(vaddr_t * pgtbl, vaddr_t va, paddr_t * pa, pte_t ** entry)[m
 {[m
 	// <lab2>[m
[32m+[m	[32mptp_t *next_ptp = (ptp_t *)(pgtbl);[m
[32m+[m	[32mpte_t *pte;[m
[32m+[m	[32mint ret;[m
[32m+[m	[32m// level 0[m
[32m+[m	[32mif((ret = get_next_ptp(next_ptp, 0, va, &next_ptp, &pte, false)) < 0){[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32m}[m
 [m
[31m-	// </lab2>[m
[32m+[m	[32m// level 1[m
[32m+[m	[32mif((ret = get_next_ptp(next_ptp, 1, va, &next_ptp, &pte, false)) < 0){[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32m}[m
[32m+[m	[32m// If the pte points to paddr directly:[m
[32m+[m	[32m// It means total levels of page table is dynamic, which is not always 4.[m
[32m+[m	[32mif(ret == BLOCK_PTP){[m
[32m+[m		[32m*pa = virt_to_phys((vaddr_t) next_ptp) + GET_VA_OFFSET_L1(va);//offset=[0:30][m
[32m+[m		[32m*entry = pte;[m
[32m+[m		[32mreturn 0;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m// level 2[m
[32m+[m	[32mif((ret = get_next_ptp(next_ptp, 2, va, &next_ptp, &pte, false)) < 0){[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32m}[m
[32m+[m	[32mif(ret == BLOCK_PTP){[m
[32m+[m		[32m*pa = virt_to_phys((vaddr_t) next_ptp) + GET_VA_OFFSET_L2(va);//offset=[0:21][m
[32m+[m		[32m*entry = pte;[m
[32m+[m		[32mreturn 0;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m// level 3[m
[32m+[m	[32mif((ret = get_next_ptp(next_ptp, 3, va, &next_ptp, &pte, false)) < 0){[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32m}[m
[32m+[m	[32m// must points to the paddr directly[m
[32m+[m	[32m*pa = virt_to_phys((vaddr_t) next_ptp) + GET_VA_OFFSET_L3(va);//offset=[0:12][m
[32m+[m	[32m*entry = pte;[m
 	return 0;[m
[32m+[m	[32m// ptp_t *cur_ptp = pgtbl;[m
[32m+[m	[32m// ptp_t *next_ptp = NULL;[m
[32m+[m	[32m// pte_t *pte = NULL;[m
[32m+[m	[32m// int ret = 0;[m
[32m+[m
[32m+[m	[32m// // L0 Table[m
[32m+[m	[32m// ret = get_next_ptp(cur_ptp, 0, va, &cur_ptp, &pte, false);[m
[32m+[m	[32m// if (ret < 0) {[m
[32m+[m	[32m// 	return ret;[m
[32m+[m	[32m// }[m
[32m+[m
[32m+[m	[32m// // L1 Table[m
[32m+[m	[32m// ret = get_next_ptp(cur_ptp, 1, va, &cur_ptp, &pte, false);[m
[32m+[m	[32m// if (ret < 0) {[m
[32m+[m	[32m// 	return ret;[m
[32m+[m	[32m// } else if (ret == BLOCK_PTP) {[m
[32m+[m	[32m// 	*pa = (pte->l1_block.pfn) << L1_INDEX_SHIFT;[m
[32m+[m	[32m// 	*pa |= GET_VA_OFFSET_L1(va);[m
[32m+[m	[32m// 	return 0;[m
[32m+[m	[32m// }[m
[32m+[m
[32m+[m	[32m// // L2 Table[m
[32m+[m	[32m// ret = get_next_ptp(cur_ptp, 2, va, &cur_ptp, &pte, false);[m
[32m+[m	[32m// if (ret < 0) {[m
[32m+[m	[32m// 	return ret;[m
[32m+[m	[32m// } else if (ret == BLOCK_PTP) {[m
[32m+[m	[32m// 	*pa = (pte->l2_block.pfn) << L2_INDEX_SHIFT;[m
[32m+[m	[32m// 	*pa |= GET_VA_OFFSET_L2(va);[m
[32m+[m	[32m// 	return 0;[m
[32m+[m	[32m// }[m
[32m+[m
[32m+[m	[32m// // L3 Table[m
[32m+[m	[32m// ret = get_next_ptp(cur_ptp, 3, va, &cur_ptp, &pte, false);[m
[32m+[m	[32m// if (ret < 0) {[m
[32m+[m	[32m// 	return ret;[m
[32m+[m	[32m// }[m
[32m+[m
[32m+[m	[32m// *pa = (pte->l3_page.pfn) << L3_INDEX_SHIFT;[m
[32m+[m	[32m// *pa |= GET_VA_OFFSET_L3(va);[m
[32m+[m	[32m// return 0;[m
[32m+[m	[32m// </lab2>[m
 }[m
 [m
 /*[m
[36m@@ -186,9 +262,53 @@[m [mint map_range_in_pgtbl(vaddr_t * pgtbl, vaddr_t va, paddr_t pa,[m
 		       size_t len, vmr_prop_t flags)[m
 {[m
 	// <lab2>[m
[32m+[m	[32mptp_t *ptp_0 = (ptp_t *)(pgtbl), *ptp_1, *ptp_2, *ptp_3, *next_ptp;[m
[32m+[m	[32mpte_t *pte_0, *pte_1, *pte_2, *pte_3;[m
[32m+[m	[32mint ret;[m
[32m+[m	[32msize_t page_num = ROUND_UP(len, PAGE_SIZE) / PAGE_SIZE;[m
[32m+[m	[32mfor(size_t i = 0;i < page_num;i++, va += PAGE_SIZE, pa += PAGE_SIZE){[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_0, 0, va, &ptp_1, &pte_0, true)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_1, 1, va, &ptp_2, &pte_1, true)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_2, 2, va, &ptp_3, &pte_2, true)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_3, 3, va, &next_ptp, &pte_3, true)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
 [m
[31m-	// </lab2>[m
[32m+[m		[32mset_pte_flags(pte_3, flags, USER_PTE);[m
[32m+[m		[32mpte_3->l3_page.pfn = pa >> PAGE_SHIFT;[m
[32m+[m		[32mpte_3->l3_page.is_valid = 1;[m
[32m+[m		[32mpte_3->l3_page.is_page = 1;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mflush_tlb();[m
 	return 0;[m
[32m+[m	[32m// len = ROUND_UP(len, PAGE_SIZE);[m
[32m+[m	[32m// for (vaddr_t va_end = va + len; va < va_end; pa += PAGE_SIZE, va += PAGE_SIZE) {[m
[32m+[m	[32m// 	ptp_t *cur_ptp = pgtbl;[m
[32m+[m	[32m// 	pte_t *pte = NULL;[m
[32m+[m	[32m// 	for (u32 level = 0; level <= 2; ++level) {[m
[32m+[m	[32m// 		int ret = get_next_ptp(cur_ptp, level, va, &cur_ptp, &pte, true);[m
[32m+[m	[32m// 		if (ret < 0) {[m
[32m+[m	[32m// 			return ret;[m
[32m+[m	[32m// 		}[m
[32m+[m	[32m// 	}[m
[32m+[m	[32m// 	// cur_ptp now points to L3 page table[m
[32m+[m	[32m// 	pte = &(cur_ptp->ent[GET_L3_INDEX(va)]);[m
[32m+[m	[32m// 	pte->pte = 0;[m
[32m+[m	[32m// 	pte->l3_page.is_valid = 1;[m
[32m+[m	[32m// 	pte->l3_page.is_page = 1;[m
[32m+[m	[32m// 	pte->l3_page.pfn = (pa) >> PAGE_SHIFT;[m
[32m+[m	[32m// 	set_pte_flags(pte, flags, USER_PTE);[m
[32m+[m	[32m// }[m
[32m+[m	[32m// flush_tlb();[m
[32m+[m	[32m// return 0;[m
[32m+[m	[32m// </lab2>[m
 }[m
 [m
 [m
[36m@@ -207,9 +327,54 @@[m [mint map_range_in_pgtbl(vaddr_t * pgtbl, vaddr_t va, paddr_t pa,[m
 int unmap_range_in_pgtbl(vaddr_t * pgtbl, vaddr_t va, size_t len)[m
 {[m
 	// <lab2>[m
[32m+[m	[32mptp_t *ptp_0 = (ptp_t *)(pgtbl), *ptp_1, *ptp_2, *ptp_3, *next_ptp;[m
[32m+[m	[32mpte_t *pte_0, *pte_1, *pte_2, *pte_3;[m
[32m+[m	[32mint ret;[m
[32m+[m	[32msize_t page_num = ROUND_UP(len, PAGE_SIZE) / PAGE_SIZE;[m
[32m+[m	[32mfor(size_t i = 0;i < page_num;i++, va += PAGE_SIZE){[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_0, 0, va, &ptp_1, &pte_0, false)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
 [m
[31m-	// </lab2>[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_1, 1, va, &ptp_2, &pte_1, false)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
[32m+[m		[32mif(ret == BLOCK_PTP){[m
[32m+[m			[32mpte_1->l1_block.is_valid = 0;[m
[32m+[m			[32mcontinue;[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_2, 2, va, &ptp_3, &pte_2, false)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
[32m+[m		[32mif(ret == BLOCK_PTP){[m
[32m+[m			[32mpte_2->l2_block.is_valid = 0;[m
[32m+[m			[32mcontinue;[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mif((ret = get_next_ptp(ptp_3, 3, va, &next_ptp, &pte_3, true)) < 0){[m
[32m+[m			[32mreturn ret;[m
[32m+[m		[32m}[m
[32m+[m		[32mpte_3->l3_page.is_valid = 0;[m
[32m+[m
[32m+[m	[32m}[m
[32m+[m	[32mflush_tlb();[m
 	return 0;[m
[32m+[m	[32m// len = ROUND_UP(len, PAGE_SIZE);[m
[32m+[m	[32m// for (vaddr_t va_end = va + len; va < va_end; va += PAGE_SIZE) {[m
[32m+[m	[32m// 	ptp_t *cur_ptp = pgtbl;[m
[32m+[m	[32m// 	pte_t *pte = NULL;[m
[32m+[m	[32m// 	for (u32 level = 0; level <= 3; ++level) {[m
[32m+[m	[32m// 		int ret = get_next_ptp(cur_ptp, level, va, &cur_ptp, &pte, false);[m
[32m+[m	[32m// 		if (ret < 0) {[m
[32m+[m	[32m// 			continue;[m
[32m+[m	[32m// 		}[m
[32m+[m	[32m// 	}[m
[32m+[m	[32m// 	pte->pte = 0;[m
[32m+[m	[32m// }[m
[32m+[m	[32m// flush_tlb();[m
[32m+[m	[32m// return 0;[m
[32m+[m	[32m// </lab2>[m
 }[m
 [m
 // TODO: add hugepage support for user space.[m
[1mdiff --git a/kernel/mm/page_table.h b/kernel/mm/page_table.h[m
[1mindex 02e4ed5..8763735 100644[m
[1m--- a/kernel/mm/page_table.h[m
[1m+++ b/kernel/mm/page_table.h[m
[36m@@ -126,3 +126,6 @@[m [mtypedef union {[m
 typedef struct {[m
 	pte_t ent[PTP_ENTRIES];[m
 } ptp_t;[m
[32m+[m
[32m+[m[32m/* page table ops func. */[m
[32m+[m[32m// int get_next_ptp(ptp_t * cur_ptp, u32 level, vaddr_t va, ptp_t ** next_ptp, pte_t ** pte, bool alloc);[m
[1mdiff --git a/kernel/mm/slab.h b/kernel/mm/slab.h[m
[1mindex fd452a5..056e167 100644[m
[1m--- a/kernel/mm/slab.h[m
[1m+++ b/kernel/mm/slab.h[m
[36m@@ -36,4 +36,3 @@[m [mvoid init_slab(void);[m
 [m
 void *alloc_in_slab(u64);[m
 void free_in_slab(void *addr);[m
[31m-[m
[1mdiff --git a/kernel/mm/vm_syscall.c b/kernel/mm/vm_syscall.c[m
[1mindex e567303..68af4ca 100644[m
[1m--- a/kernel/mm/vm_syscall.c[m
[1m+++ b/kernel/mm/vm_syscall.c[m
[36m@@ -48,7 +48,6 @@[m [mint sys_create_pmo(u64 size, u64 type)[m
 	int cap, r;[m
 	struct pmobject *pmo;[m
 [m
[31m-	kinfo("sys_create_pmo called\n");[m
 	BUG_ON(size == 0);[m
 	pmo = obj_alloc(TYPE_PMO, sizeof(*pmo));[m
 	if (!pmo) {[m
[36m@@ -128,6 +127,7 @@[m [mstatic int read_write_pmo(u64 pmo_cap, u64 offset, u64 user_buf,[m
 		r = -ECAPBILITY;[m
 		goto out_fail;[m
 	}[m
[32m+[m
 	/* we only allow writing PMO_DATA now. */[m
 	if (pmo->type != PMO_DATA) {[m
 		r = -EINVAL;[m
[36m@@ -180,7 +180,6 @@[m [mint sys_map_pmo(u64 target_process_cap, u64 pmo_cap, u64 addr, u64 perm)[m
 	struct process *target_process;[m
 	int r;[m
 [m
[31m-	kinfo("sys_map_pmo called\n");[m
 	pmo = obj_get(current_process, pmo_cap, TYPE_PMO);[m
 	if (!pmo) {[m
 		r = -ECAPBILITY;[m
[36m@@ -295,6 +294,7 @@[m [mint sys_unmap_pmo(u64 target_process_cap, u64 pmo_cap, u64 addr)[m
 		ret = -EPERM;[m
 		goto fail2;[m
 	}[m
[32m+[m
 	ret = vmspace_unmap_range(vmspace, addr, pmo->size);[m
 	if (ret != 0)[m
 		ret = -EPERM;[m
[36m@@ -347,11 +347,37 @@[m [mu64 sys_handle_brk(u64 addr)[m
 	 * top.[m
 	 *[m
 	 */[m
[32m+[m	[32mif(addr == 0){[m
[32m+[m		[32m//1. Create a new pmo with size 0 and type PMO_ANONYM.[m
[32m+[m		[32mpmo = obj_alloc(TYPE_PMO, sizeof(*pmo));[m
[32m+[m		[32mif (!pmo) {//pmo allocation out of memory[m
[32m+[m			[32mretval = vmspace->user_current_heap;[m
[32m+[m			[32mgoto out_obj_put_vmspace;[m
[32m+[m		[32m}[m
[32m+[m		[32mpmo_init(pmo, PMO_ANONYM, 0, 0);//PMO_ANONYM:lazy allocation, size = 0[m
[32m+[m		[32m//2. Initialize vmspace->heap_vmr using function init_heap_vmr()[m
[32m+[m		[32mvmspace->heap_vmr = init_heap_vmr(vmspace, vmspace->user_current_heap, pmo);[m
[32m+[m		[32mretval = vmspace->user_current_heap;[m
[32m+[m		[32mgoto out_obj_put_vmspace;[m
[32m+[m	[32m}else if(addr > vmspace->user_current_heap){[m
[32m+[m		[32mvmspace->heap_vmr->size += (addr - vmspace->user_current_heap);[m
[32m+[m		[32mvmspace->heap_vmr->pmo->size += (addr - vmspace->user_current_heap);[m
[32m+[m		[32mretval = addr;[m
[32m+[m		[32mgoto out_obj_put_vmspace;[m
[32m+[m	[32m}else if(addr < vmspace->user_current_heap){[m
[32m+[m		[32mretval = -EINVAL;[m
[32m+[m		[32mgoto out_obj_put_vmspace;[m
[32m+[m	[32m}else{[m
[32m+[m		[32mretval = vmspace->user_current_heap;[m
[32m+[m		[32mgoto out_obj_put_vmspace;[m
[32m+[m	[32m}[m
 [m
 	/*[m
 	 * return origin heap addr on failure;[m
 	 * return new heap addr on success.[m
 	 */[m
[32m+[m[32mout_obj_put_vmspace:[m
 	obj_put(vmspace);[m
 	return retval;[m
[32m+[m
 }[m
[1mdiff --git a/kernel/monitor.c b/kernel/monitor.c[m
[1mindex 00dd7b5..86abc59 100644[m
[1m--- a/kernel/monitor.c[m
[1m+++ b/kernel/monitor.c[m
[36m@@ -30,6 +30,20 @@[m [mint stack_backtrace()[m
 	printk("Stack backtrace:\n");[m
 [m
 	// Your code here.[m
[32m+[m	[32mu64* fp = (u64* )(*((u64* )read_fp())); //ignore stack_backtrace func. itself[m
[32m+[m	[32m// u64* fp = (u64* )read_fp();[m
[32m+[m	[32mu64* argp;[m
[32m+[m	[32mwhile(*fp != 0){[m
[32m+[m		[32mprintk("LR %llx FP %llx ", *(fp+1), fp);[m
[32m+[m		[32mprintk("Args ");[m
[32m+[m		[32margp = fp - 2;//start addr of args[m
[32m+[m		[32mfor(int i = 5;i > 0;i--){[m
[32m+[m			[32mprintk("%llx ", *argp);[m
[32m+[m			[32margp++;[m
[32m+[m		[32m}[m
[32m+[m		[32mprintk("\n");[m
[32m+[m		[32mfp = (u64* )(*fp);//backtrace to parent func's fp[m
[32m+[m	[32m}[m
 [m
 	return 0;[m
 }[m
[1mdiff --git a/kernel/process/capability.c b/kernel/process/capability.c[m
[1mindex 1aedfc1..c92e679 100644[m
[1m--- a/kernel/process/capability.c[m
[1m+++ b/kernel/process/capability.c[m
[36m@@ -89,7 +89,7 @@[m [mvoid *obj_alloc(u64 type, u64 size)[m
 	struct object *object;[m
 [m
 	// opaque is u64 so sizeof(*object) is 8-byte aligned.[m
[31m-	// Thus the address of object-defined data is always 8-byte aligned.[m
[32m+[m	[32m//      Thus the address of object-defined data is always 8-byte aligned.[m
 	total_size = sizeof(*object) + size;[m
 	object = kmalloc(total_size);[m
 	if (!object)[m
[1mdiff --git a/kernel/process/process.c b/kernel/process/process.c[m
[1mindex a1eaa0e..fdd8ec2 100644[m
[1m--- a/kernel/process/process.c[m
[1m+++ b/kernel/process/process.c[m
[36m@@ -256,12 +256,12 @@[m [mvoid process_create_root(char *bin_name)[m
 	thread_cap = thread_create_main(root_process, ROOT_THREAD_STACK_BASE,[m
 					ROOT_THREAD_STACK_SIZE,[m
 					ROOT_THREAD_PRIO, TYPE_ROOT,[m
[31m-					0, binary, bin_name);[m
[32m+[m					[32msmp_get_cpu_id(), binary, bin_name);[m
 [m
 	root_thread = obj_get(root_process, thread_cap, TYPE_THREAD);[m
 	/* Enqueue: put init thread into the ready queue */[m
[32m+[m	[32mBUG_ON(sched_enqueue(root_thread));[m
 	obj_put(root_thread);[m
[31m-	current_thread = root_thread;[m
 }[m
 [m
 /* syscalls */[m
[1mdiff --git a/kernel/process/thread.c b/kernel/process/thread.c[m
[1mindex a222fca..4e21bf4 100644[m
[1m--- a/kernel/process/thread.c[m
[1m+++ b/kernel/process/thread.c[m
[36m@@ -21,6 +21,7 @@[m
 #include <process/thread.h>[m
 #include <sched/context.h>[m
 #include <common/registers.h>[m
[32m+[m[32m#include <common/smp.h>[m
 #include <common/cpio.h>[m
 #include <exception/exception.h>[m
 [m
[36m@@ -61,15 +62,24 @@[m [mvoid thread_deinit(void *thread_ptr)[m
 [m
 	thread = thread_ptr;[m
 [m
[31m-	object = container_of(thread, struct object, opaque);[m
[31m-	object->refcount = 1;[m
[31m-[m
[31m-	process = thread->process;[m
[31m-	list_del(&thread->node);[m
[31m-	if (list_empty(&process->thread_list))[m
[31m-		exit_process = true;[m
[31m-[m
[31m-	destroy_thread_ctx(thread);[m
[32m+[m	[32mswitch (thread->thread_ctx->state) {[m
[32m+[m	[32mcase TS_RUNNING:[m
[32m+[m		[32mobject = container_of(thread, struct object, opaque);[m
[32m+[m		[32mobject->refcount = 1;[m
[32m+[m		[32mthread->thread_ctx->state = TS_EXITING;[m
[32m+[m
[32m+[m		[32mbreak;[m
[32m+[m	[32mcase TS_READY:[m
[32m+[m		[32msched_dequeue(thread);[m
[32m+[m		[32m/* fall through */[m
[32m+[m	[32mdefault:[m
[32m+[m		[32mprocess = thread->process;[m
[32m+[m		[32mlist_del(&thread->node);[m
[32m+[m		[32mif (list_empty(&process->thread_list))[m
[32m+[m			[32mexit_process = true;[m
[32m+[m
[32m+[m		[32mdestroy_thread_ctx(thread);[m
[32m+[m	[32m}[m
 [m
 	if (exit_process)[m
 		process_exit(process);[m
[36m@@ -104,6 +114,10 @@[m [mint thread_create(struct process *process, u64 stack, u64 pc, u64 arg, u32 prio,[m
 	}[m
 	/* ret is thread_cap in the current_process */[m
 	cap = cap_copy(process, current_process, cap, 0, 0);[m
[32m+[m	[32mif (type == TYPE_USER) {[m
[32m+[m		[32mret = sched_enqueue(thread);[m
[32m+[m		[32mBUG_ON(ret);[m
[32m+[m	[32m}[m
 [m
 	/* TYPE_KERNEL => do nothing */[m
 	return cap;[m
[36m@@ -162,6 +176,11 @@[m [mstatic u64 load_binary(struct process *process,[m
 			 * and mapping physical memory.[m
 			 */[m
 [m
[32m+[m			[32m// prepare seg_map_sz(seg_sz, p_vaddr)[m
[32m+[m			[32mseg_sz = elf->p_headers[i].p_memsz;[m
[32m+[m			[32mp_vaddr = elf->p_headers[i].p_vaddr;[m
[32m+[m			[32mseg_map_sz = ROUND_UP(p_vaddr + seg_sz, PAGE_SIZE) - ROUND_DOWN(p_vaddr, PAGE_SIZE); //2-sides alignment[m
[32m+[m
 			pmo = obj_alloc(TYPE_PMO, sizeof(*pmo));[m
 			if (!pmo) {[m
 				r = -ENOMEM;[m
[36m@@ -180,6 +199,10 @@[m [mstatic u64 load_binary(struct process *process,[m
 			 * The physical address of a pmo can be get from pmo->start.[m
 			 */[m
 [m
[32m+[m			[32mmemcpy((void *)(phys_to_virt(pmo->start) + (p_vaddr - ROUND_DOWN(p_vaddr, PAGE_SIZE))),[m
[32m+[m				[32m bin + elf->p_headers[i].p_offset, elf->p_headers[i].p_filesz);[m
[32m+[m			[32m// memcpy((void *)phys_to_virt(pmo->start), p_vaddr, seg_sz);[m
[32m+[m
 			flags = PFLAGS2VMRFLAGS(elf->p_headers[i].p_flags);[m
 [m
 			ret = vmspace_map_range(vmspace,[m
[36m@@ -313,14 +336,80 @@[m [mvoid switch_thread_vmspace_to(struct thread *thread)[m
 /* Exit the current running thread */[m
 void sys_exit(int ret)[m
 {[m
[31m-	int cpuid = 0;[m
[32m+[m	[32mint cpuid = smp_get_cpu_id();[m
 	struct thread *target = current_threads[cpuid];[m
 [m
[31m-	kinfo("sys_exit with value %d\n", ret);[m
[32m+[m	[32m// kinfo("sys_exit with value %d\n", ret);[m
 	/* Set thread state */[m
[32m+[m	[32mtarget->thread_ctx->state = TS_EXIT;[m
 	obj_free(target);[m
 [m
 	/* Set current running thread to NULL */[m
 	current_threads[cpuid] = NULL;[m
[31m-	break_point();[m
[32m+[m	[32m/* Reschedule */[m
[32m+[m	[32mcur_sched_ops->sched();[m
[32m+[m	[32meret_to_thread(switch_context());[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * create a thread in some process[m
[32m+[m[32m * return the thread_cap in the target process[m
[32m+[m[32m */[m
[32m+[m[32mint sys_create_thread(u64 process_cap, u64 stack, u64 pc, u64 arg, u32 prio,[m
[32m+[m		[32m      s32 aff)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct process *process =[m
[32m+[m	[32m    obj_get(current_process, process_cap, TYPE_PROCESS);[m
[32m+[m	[32mint thread_cap =[m
[32m+[m	[32m    thread_create(process, stack, pc, arg, prio, TYPE_USER, aff);[m
[32m+[m
[32m+[m	[32mobj_put(process);[m
[32m+[m	[32mreturn thread_cap;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Finish the sys_set_affinity[m
[32m+[m[32m * You do not need to schedule out current thread immediately,[m
[32m+[m[32m * as it is the duty of sys_yield()[m
[32m+[m[32m */[m
[32m+[m[32mint sys_set_affinity(u64 thread_cap, s32 aff)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *thread = NULL;[m
[32m+[m	[32mint cpuid = smp_get_cpu_id(), ret = 0;[m
[32m+[m
[32m+[m	[32m/* currently, we use -1 to represent the current thread */[m
[32m+[m	[32mif (thread_cap == -1) {[m
[32m+[m		[32mthread = current_threads[cpuid];[m
[32m+[m		[32mBUG_ON(!thread);[m
[32m+[m	[32m} else {[m
[32m+[m		[32mthread = obj_get(current_process, thread_cap, TYPE_THREAD);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/*[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Finish the sys_set_affinity[m
[32m+[m	[32m */[m
[32m+[m	[32mreturn -1;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint sys_get_affinity(u64 thread_cap)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *thread = NULL;[m
[32m+[m	[32mint cpuid = smp_get_cpu_id();[m
[32m+[m	[32ms32 aff = 0;[m
[32m+[m
[32m+[m	[32m/* currently, we use -1 to represent the current thread */[m
[32m+[m	[32mif (thread_cap == -1) {[m
[32m+[m		[32mthread = current_threads[cpuid];[m
[32m+[m		[32mBUG_ON(!thread);[m
[32m+[m	[32m} else {[m
[32m+[m		[32mthread = obj_get(current_process, thread_cap, TYPE_THREAD);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/*[m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Finish the sys_get_affinity[m
[32m+[m	[32m */[m
[32m+[m	[32mreturn -1;[m
 }[m
[1mdiff --git a/kernel/process/thread.h b/kernel/process/thread.h[m
[1mindex 9021295..471ac33 100644[m
[1m--- a/kernel/process/thread.h[m
[1m+++ b/kernel/process/thread.h[m
[36m@@ -16,9 +16,11 @@[m
 #include <mm/vmspace.h>[m
 #include <sched/sched.h>[m
 #include <process/process.h>[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <ipc/ipc.h>[m
 [m
 extern struct thread *current_threads[PLAT_CPU_NUM];[m
[31m-#define current_thread (current_threads[0])[m
[32m+[m[32m#define current_thread (current_threads[smp_get_cpu_id()])[m
 #define DEFAULT_KERNEL_STACK_SZ		(0x1000)[m
 [m
 /* Arguments for the inital thread */[m
[36m@@ -28,10 +30,15 @@[m [mextern struct thread *current_threads[PLAT_CPU_NUM];[m
 [m
 struct thread {[m
 	struct list_head node;	// link threads in a same process[m
[32m+[m	[32mstruct list_head ready_queue_node;	// link threads in a ready queue[m
[32m+[m	[32mstruct list_head notification_queue_node;	// link threads in a notification waiting queue[m
 	struct thread_ctx *thread_ctx;	// thread control block[m
 	struct vmspace *vmspace;	// memory mapping[m
 [m
 	struct process *process;[m
[32m+[m
[32m+[m	[32mstruct ipc_connection *active_conn;[m
[32m+[m	[32mstruct server_ipc_config *server_ipc_config;[m
 };[m
 [m
 void switch_thread_vmspace_to(struct thread *);[m
[1mdiff --git a/kernel/sched/context.c b/kernel/sched/context.c[m
[1mindex 09d3c8e..e4a05df 100644[m
[1m--- a/kernel/sched/context.c[m
[1m+++ b/kernel/sched/context.c[m
[36m@@ -12,6 +12,7 @@[m
 [m
 #include <common/kmalloc.h>[m
 #include <common/kprint.h>[m
[32m+[m[32m#include <common/smp.h>[m
 #include <common/util.h>[m
 #include <common/registers.h>[m
 #include <process/thread.h>[m
[36m@@ -56,9 +57,23 @@[m [mvoid init_thread_ctx(struct thread *thread, u64 stack, u64 func, u32 prio,[m
 	 */[m
 [m
 	/* Fill the context of the thread */[m
[32m+[m	[32mthread->thread_ctx->ec.reg[SP_EL0] = stack; //1. Set SP_EL0 to stack.[m
[32m+[m	[32mthread->thread_ctx->ec.reg[ELR_EL1] = func; //2. Set ELR_EL1 to the entrypoint of this thread.[m
[32m+[m	[32mthread->thread_ctx->ec.reg[SPSR_EL1] = SPSR_EL1_EL0t; //3. Set SPSR_EL1 to SPSR_EL1_EL0t as the properly PSTATE.[m
 [m
 	/* Set thread type */[m
 	thread->thread_ctx->type = type;[m
[32m+[m
[32m+[m	[32m/* Set the priority and state of the thread */[m
[32m+[m	[32mthread->thread_ctx->prio = prio;[m
[32m+[m	[32mthread->thread_ctx->state = TS_INIT;[m
[32m+[m
[32m+[m	[32m/* Set the cpuid and affinity */[m
[32m+[m	[32mthread->thread_ctx->affinity = aff;[m
[32m+[m
[32m+[m	[32m/* Set the budget of the thread */[m
[32m+[m	[32mthread->thread_ctx->sc = kmalloc(sizeof(sched_cont_t));[m
[32m+[m	[32mthread->thread_ctx->sc->budget = DEFAULT_BUDGET;[m
 }[m
 [m
 u64 arch_get_thread_stack(struct thread *thread)[m
[1mdiff --git a/kernel/sched/idle.S b/kernel/sched/idle.S[m
[1mnew file mode 100644[m
[1mindex 0000000..b02739c[m
[1m--- /dev/null[m
[1m+++ b/kernel/sched/idle.S[m
[36m@@ -0,0 +1,6 @@[m
[32m+[m[32m#include <common/asm.h>[m
[32m+[m[32m#include <common/vars.h>[m
[32m+[m
[32m+[m[32mBEGIN_FUNC(idle_thread_routine)[m
[32m+[m[32m        b .[m
[32m+[m[32mEND_FUNC(idle_thread_routine)[m
[1mdiff --git a/kernel/sched/policy_rr.c b/kernel/sched/policy_rr.c[m
[1mnew file mode 100644[m
[1mindex 0000000..1ce3b5e[m
[1m--- /dev/null[m
[1m+++ b/kernel/sched/policy_rr.c[m
[36m@@ -0,0 +1,152 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m[32m/* Scheduler related functions are implemented here */[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/machine.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <common/list.h>[m
[32m+[m[32m#include <common/util.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <exception/irq.h>[m
[32m+[m[32m#include <sched/context.h>[m
[32m+[m
[32m+[m[32m/* in arch/sched/idle.S */[m
[32m+[m[32mvoid idle_thread_routine(void);[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * rr_ready_queue[m
[32m+[m[32m * Per-CPU ready queue for ready tasks.[m
[32m+[m[32m */[m
[32m+[m[32mstruct list_head rr_ready_queue[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * RR policy also has idle threads.[m
[32m+[m[32m * When no active user threads in ready queue,[m
[32m+[m[32m * we will choose the idle thread to execute.[m
[32m+[m[32m * Idle thread will **NOT** be in the RQ.[m
[32m+[m[32m */[m
[32m+[m[32mstruct thread idle_threads[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Sched_enqueue[m
[32m+[m[32m * Put `thread` at the end of ready queue of assigned `affinity`.[m
[32m+[m[32m * If affinity = NO_AFF, assign the core to the current cpu.[m
[32m+[m[32m * If the thread is IDEL thread, do nothing![m
[32m+[m[32m * Do not forget to check if the affinity is valid![m
[32m+[m[32m */[m
[32m+[m[32mint rr_sched_enqueue(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn -1;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Sched_dequeue[m
[32m+[m[32m * remove `thread` from its current residual ready queue[m
[32m+[m[32m * Do not forget to add some basic parameter checking[m
[32m+[m[32m */[m
[32m+[m[32mint rr_sched_dequeue(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn -1;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * The helper function[m
[32m+[m[32m * Choose an appropriate thread and dequeue from ready queue[m
[32m+[m[32m *[m[41m [m
[32m+[m[32m * If there is no ready thread in the current CPU's ready queue,[m[41m [m
[32m+[m[32m * choose the idle thread of the CPU.[m
[32m+[m[32m *[m[41m [m
[32m+[m[32m * Do not forget to check the type and[m[41m [m
[32m+[m[32m * state of the chosen thread[m
[32m+[m[32m */[m
[32m+[m[32mstruct thread *rr_sched_choose_thread(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn NULL;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic inline void rr_sched_refill_budget(struct thread *target, u32 budget)[m
[32m+[m[32m{[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Schedule a thread to execute.[m
[32m+[m[32m * This function will suspend current running thread, if any, and schedule[m
[32m+[m[32m * another thread from `rr_ready_queue[cpu_id]`.[m
[32m+[m[32m *[m[41m [m
[32m+[m[32m * Hints:[m
[32m+[m[32m * Macro DEFAULT_BUDGET defines the value for resetting thread's budget.[m
[32m+[m[32m * After you get one thread from rr_sched_choose_thread, pass it to[m
[32m+[m[32m * switch_to_thread() to prepare for switch_context().[m
[32m+[m[32m * Then ChCore can call eret_to_thread() to return to user mode.[m
[32m+[m[32m */[m
[32m+[m[32mint rr_sched(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn -1;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Initialize the per thread queue and idle thread.[m
[32m+[m[32m */[m
[32m+[m[32mint rr_sched_init(void)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m
[32m+[m	[32m/* Initialize global variables */[m
[32m+[m	[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m		[32mcurrent_threads[i] = NULL;[m
[32m+[m		[32minit_list_head(&rr_ready_queue[i]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/* Initialize one idle thread for each core and insert into the RQ */[m
[32m+[m	[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m		[32m/* Set the thread context of the idle threads */[m
[32m+[m		[32mBUG_ON(!(idle_threads[i].thread_ctx = create_thread_ctx()));[m
[32m+[m		[32m/* We will set the stack and func ptr in arch_idle_ctx_init */[m
[32m+[m		[32minit_thread_ctx(&idle_threads[i], 0, 0, MIN_PRIO, TYPE_IDLE, i);[m
[32m+[m		[32m/* Call arch-dependent function to fill the context of the idle[m
[32m+[m		[32m * threads */[m
[32m+[m		[32march_idle_ctx_init(idle_threads[i].thread_ctx,[m
[32m+[m				[32m   idle_thread_routine);[m
[32m+[m		[32m/* Idle thread is kernel thread which do not have vmspace */[m
[32m+[m		[32midle_threads[i].vmspace = NULL;[m
[32m+[m	[32m}[m
[32m+[m	[32mkdebug("Scheduler initialized. Create %d idle threads.\n", i);[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Handler called each time a timer interrupt is handled[m
[32m+[m[32m * Do not forget to call sched_handle_timer_irq() in proper code location.[m
[32m+[m[32m */[m
[32m+[m[32mvoid rr_sched_handle_timer_irq(void)[m
[32m+[m[32m{[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstruct sched_ops rr = {[m
[32m+[m	[32m.sched_init = rr_sched_init,[m
[32m+[m	[32m.sched = rr_sched,[m
[32m+[m	[32m.sched_enqueue = rr_sched_enqueue,[m
[32m+[m	[32m.sched_dequeue = rr_sched_dequeue,[m
[32m+[m	[32m.sched_choose_thread = rr_sched_choose_thread,[m
[32m+[m	[32m.sched_handle_timer_irq = rr_sched_handle_timer_irq,[m
[32m+[m[32m};[m
[1mdiff --git a/kernel/sched/sched.c b/kernel/sched/sched.c[m
[1mindex 3056f76..7744d06 100644[m
[1m--- a/kernel/sched/sched.c[m
[1m+++ b/kernel/sched/sched.c[m
[36m@@ -12,6 +12,7 @@[m
 [m
 /* Scheduler related functions are implemented here */[m
 #include <sched/sched.h>[m
[32m+[m[32m#include <common/smp.h>[m
 #include <common/kprint.h>[m
 #include <common/machine.h>[m
 #include <common/kmalloc.h>[m
[36m@@ -26,6 +27,9 @@[m
 [m
 struct thread *current_threads[PLAT_CPU_NUM];[m
 [m
[32m+[m[32m/* Chosen Scheduling Policies */[m
[32m+[m[32mstruct sched_ops *cur_sched_ops;[m
[32m+[m
 char thread_type[][TYPE_STR_LEN] = {[m
 	"IDLE  ",[m
 	"ROOT  ",[m
[36m@@ -45,6 +49,59 @@[m [mchar thread_state[][STATE_STR_LEN] = {[m
 	"TS_EXITING   "[m
 };[m
 [m
[32m+[m[32mvoid arch_idle_ctx_init(struct thread_ctx *idle_ctx, void (*func) (void))[m
[32m+[m[32m{[m
[32m+[m	[32m/* Initialize to run the function `idle_thread_routine` */[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32march_exec_cont_t *ec = &(idle_ctx->ec);[m
[32m+[m
[32m+[m	[32m/* X0-X30 all zero */[m
[32m+[m	[32mfor (i = 0; i < REG_NUM; i++)[m
[32m+[m		[32mec->reg[i] = 0;[m
[32m+[m	[32m/* SPSR_EL1 => Exit to EL1 */[m
[32m+[m	[32mec->reg[SPSR_EL1] = SPSR_EL1_KERNEL;[m
[32m+[m	[32m/* ELR_EL1 => Next PC */[m
[32m+[m	[32mec->reg[ELR_EL1] = (u64) func;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid print_thread(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mprintk[m
[32m+[m	[32m    ("Thread %p\tType: %s\tState: %s\tCPU %d\tAFF %d\tBudget %d\tPrio: %d\t\n",[m
[32m+[m	[32m     thread, thread_type[thread->thread_ctx->type],[m
[32m+[m	[32m     thread_state[thread->thread_ctx->state], thread->thread_ctx->cpuid,[m
[32m+[m	[32m     thread->thread_ctx->affinity, thread->thread_ctx->sc->budget,[m
[32m+[m	[32m     thread->thread_ctx->prio);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint sched_is_running(struct thread *target)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(!target);[m
[32m+[m	[32mBUG_ON(!target->thread_ctx);[m
[32m+[m
[32m+[m	[32mif (target->thread_ctx->state == TS_RUNNING)[m
[32m+[m		[32mreturn 1;[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * Switch Thread to the specified one.[m
[32m+[m[32m * Set the correct thread state to running and the current_thread[m
[32m+[m[32m */[m
[32m+[m[32mint switch_to_thread(struct thread *target)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(!target);[m
[32m+[m	[32mBUG_ON(!target->thread_ctx);[m
[32m+[m	[32mBUG_ON((target->thread_ctx->state == TS_READY));[m
[32m+[m
[32m+[m	[32mtarget->thread_ctx->cpuid = smp_get_cpu_id();[m
[32m+[m	[32mtarget->thread_ctx->state = TS_RUNNING;[m
[32m+[m	[32msmp_wmb();[m
[32m+[m	[32mcurrent_thread = target;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
 /*[m
  * Switch vmspace and arch-related stuff[m
  * Return the context pointer which should be set to stack pointer register[m
[36m@@ -79,5 +136,25 @@[m [mu64 switch_context(void)[m
 	 * Return the correct value in order to make eret_to_thread work correctly[m
 	 * in main.c[m
 	 */[m
[32m+[m
[32m+[m	[32mreturn (u64)(target_ctx->ec.reg); //protected mode, return virtual addr.[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/* SYSCALL functions */[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Lab4[m[41m [m
[32m+[m[32m * Finish the sys_yield function[m
[32m+[m[32m */[m
[32m+[m[32mvoid sys_yield(void)[m
[32m+[m[32m{[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint sched_init(struct sched_ops *sched_ops)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(sched_ops == NULL);[m
[32m+[m
[32m+[m	[32mcur_sched_ops = sched_ops;[m
[32m+[m	[32mcur_sched_ops->sched_init();[m
 	return 0;[m
 }[m
[1mdiff --git a/kernel/sched/sched.h b/kernel/sched/sched.h[m
[1mindex b38699f..d5e355d 100644[m
[1m--- a/kernel/sched/sched.h[m
[1m+++ b/kernel/sched/sched.h[m
[36m@@ -72,12 +72,82 @@[m [mstruct thread_ctx {[m
 	/* Executing Context */[m
 	arch_exec_cont_t ec;[m
 [m
[32m+[m	[32m/* Scheduling Context */[m
[32m+[m	[32msched_cont_t *sc;[m
[32m+[m
 	/* Thread Type */[m
 	u32 type;[m
[32m+[m
[32m+[m	[32m/* Thread state */[m
[32m+[m	[32mu32 state;[m
[32m+[m
[32m+[m	[32m/* Priority */[m
[32m+[m	[32mu32 prio;[m
[32m+[m
[32m+[m	[32m/* SMP Affinity */[m
[32m+[m	[32ms32 affinity;[m
[32m+[m
[32m+[m	[32m/* Current Assigned CPU */[m
[32m+[m	[32mu32 cpuid;[m
 };[m
 [m
[32m+[m[32m/* Debug functions */[m
[32m+[m[32mvoid print_thread(struct thread *thread);[m
[32m+[m
 extern char thread_type[][TYPE_STR_LEN];[m
 extern char thread_state[][STATE_STR_LEN];[m
 [m
[32m+[m[32mvoid arch_idle_ctx_init(struct thread_ctx *idle_ctx, void (*func) (void));[m
 u64 switch_context(void);[m
[32m+[m[32mint sched_is_runnable(struct thread *target);[m
[32m+[m[32mint sched_is_running(struct thread *target);[m
[32m+[m[32mint switch_to_thread(struct thread *target);[m
[32m+[m
[32m+[m[32m/* Global-shared kernel data */[m
[32m+[m[32mextern struct list_head ready_queue[PLAT_CPU_NUM][PRIO_NUM];[m
[32m+[m[32mextern struct thread *current_threads[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32m/* Indirect function call may downgrade performance */[m
[32m+[m[32mstruct sched_ops {[m
[32m+[m	[32mint (*sched_init) (void);[m
[32m+[m	[32mint (*sched) (void);[m
[32m+[m	[32mint (*sched_enqueue) (struct thread * thread);[m
[32m+[m	[32mint (*sched_dequeue) (struct thread * thread);[m
[32m+[m	[32mstruct thread *(*sched_choose_thread) (void);[m
[32m+[m	[32mvoid (*sched_handle_timer_irq) (void);[m
[32m+[m	[32m/* Debug tools */[m
[32m+[m	[32mvoid (*sched_top) (void);[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m/* Provided Scheduling Policies */[m
[32m+[m[32mextern struct sched_ops rr;	/* Simple Round Robin */[m
[32m+[m
[32m+[m[32m/* Chosen Scheduling Policies */[m
[32m+[m[32mextern struct sched_ops *cur_sched_ops;[m
[32m+[m
[32m+[m[32mint sched_init(struct sched_ops *sched_ops);[m
[32m+[m
[32m+[m[32mstatic inline int sched(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn cur_sched_ops->sched();[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic inline int sched_enqueue(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn cur_sched_ops->sched_enqueue(thread);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic inline int sched_dequeue(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn cur_sched_ops->sched_dequeue(thread);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic inline struct thread *sched_choose_thread(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn cur_sched_ops->sched_choose_thread();[m
[32m+[m[32m}[m
 [m
[32m+[m[32mstatic inline void sched_handle_timer_irq(void)[m
[32m+[m[32m{[m
[32m+[m	[32mcur_sched_ops->sched_handle_timer_irq();[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/syscall/syscall.c b/kernel/syscall/syscall.c[m
[1mindex b1c9111..170fbf4 100644[m
[1m--- a/kernel/syscall/syscall.c[m
[1m+++ b/kernel/syscall/syscall.c[m
[36m@@ -12,10 +12,12 @@[m
 [m
 #include <common/types.h>[m
 #include <common/uart.h>[m
[32m+[m[32m#include <common/smp.h>[m
 #include <common/uaccess.h>[m
 #include <common/kmalloc.h>[m
 #include <common/mm.h>[m
 #include <common/kprint.h>[m
[32m+[m[32m#include <common/fs.h>[m
 #include "syscall_num.h"[m
 [m
 void sys_debug(long arg)[m
[36m@@ -29,6 +31,21 @@[m [mvoid sys_putc(char ch)[m
 	 * Lab3: Your code here[m
 	 * Send ch to the screen in anyway as your like[m
 	 */[m
[32m+[m	[32muart_send(ch);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mu32 sys_getc(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn uart_recv();[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/*[m[41m [m
[32m+[m[32m * Lab4[m
[32m+[m[32m * Finish the sys_get_cpu_id syscall[m
[32m+[m[32m */[m
[32m+[m[32mu32 sys_get_cpu_id(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn -1;[m
 }[m
 [m
 /*[m
[36m@@ -37,6 +54,42 @@[m [mvoid sys_putc(char ch)[m
  * to functions accordingly[m
  */[m
 const void *syscall_table[NR_SYSCALL] = {[m
[31m-	[0 ... NR_SYSCALL - 1] = sys_debug,[m
[32m+[m	[32m/* lab3 syscalls*/[m
[32m+[m	[32m[SYS_putc] = sys_putc,[m
[32m+[m	[32m[SYS_exit] = sys_exit,[m
[32m+[m	[32m[SYS_create_pmo] = sys_create_pmo,[m
[32m+[m	[32m[SYS_map_pmo] = sys_map_pmo,[m
[32m+[m	[32m[SYS_handle_brk] = sys_handle_brk,[m
 	/* lab3 syscalls finished */[m
[32m+[m
[32m+[m	[32m[SYS_getc] = sys_getc,[m
[32m+[m	[32m[SYS_yield] = sys_yield,[m
[32m+[m	[32m[SYS_create_device_pmo] = sys_create_device_pmo,[m
[32m+[m	[32m[SYS_unmap_pmo] = sys_unmap_pmo,[m
[32m+[m	[32m[SYS_create_thread] = sys_create_thread,[m
[32m+[m	[32m[SYS_create_process] = sys_create_process,[m
[32m+[m	[32m[SYS_register_server] = sys_register_server,[m
[32m+[m	[32m[SYS_register_client] = sys_register_client,[m
[32m+[m	[32m[SYS_ipc_call] = sys_ipc_call,[m
[32m+[m	[32m[SYS_ipc_return] = sys_ipc_return,[m
[32m+[m	[32m[SYS_cap_copy_to] = sys_cap_copy_to,[m
[32m+[m	[32m[SYS_cap_copy_from] = sys_cap_copy_from,[m
[32m+[m	[32m[SYS_set_affinity] = sys_set_affinity,[m
[32m+[m	[32m[SYS_get_affinity] = sys_get_affinity,[m
[32m+[m	[32m/*[m[41m [m
[32m+[m	[32m * Lab4[m
[32m+[m	[32m * Add syscall[m
[32m+[m	[32m */[m
[32m+[m	[32m[SYS_get_cpu_id] = sys_get_cpu_id,[m
[32m+[m
[32m+[m	[32m[SYS_create_pmos] = sys_create_pmos,[m
[32m+[m	[32m[SYS_map_pmos] = sys_map_pmos,[m
[32m+[m	[32m[SYS_write_pmo] = sys_write_pmo,[m
[32m+[m	[32m[SYS_read_pmo] = sys_read_pmo,[m
[32m+[m	[32m[SYS_transfer_caps] = sys_transfer_caps,[m
[32m+[m
[32m+[m	[32m/* TMP FS */[m
[32m+[m	[32m[SYS_fs_load_cpio] = sys_fs_load_cpio,[m
[32m+[m
[32m+[m	[32m[SYS_debug] = sys_debug[m
 };[m
[1mdiff --git a/kernel/syscall/syscall_num.h b/kernel/syscall/syscall_num.h[m
[1mindex 0c5f952..763823e 100644[m
[1m--- a/kernel/syscall/syscall_num.h[m
[1m+++ b/kernel/syscall/syscall_num.h[m
[36m@@ -20,6 +20,28 @@[m [mvoid sys_map_pmo(void);[m
 void sys_handle_brk(void);[m
 /* lab3 syscalls finished */[m
 [m
[32m+[m[32mvoid sys_yield(void);[m
[32m+[m[32mvoid sys_create_device_pmo(void);[m
[32m+[m[32mvoid sys_create_thread(void);[m
[32m+[m[32mvoid sys_create_process(void);[m
[32m+[m[32mvoid sys_cap_copy_to(void);[m
[32m+[m[32mvoid sys_cap_copy_from(void);[m
[32m+[m[32mvoid sys_unmap_pmo(void);[m
[32m+[m[32mvoid sys_set_affinity(void);[m
[32m+[m[32mvoid sys_get_affinity(void);[m
[32m+[m
[32m+[m[32mvoid sys_create_pmos(void);[m
[32m+[m[32mvoid sys_map_pmos(void);[m
[32m+[m[32mvoid sys_write_pmo(void);[m
[32m+[m[32mvoid sys_transfer_caps(void);[m
[32m+[m[32mvoid sys_read_pmo(void);[m
[32m+[m
[32m+[m[32mvoid sys_register_server(void);[m
[32m+[m[32mvoid sys_register_client(void);[m
[32m+[m[32mvoid sys_ipc_call(void);[m
[32m+[m[32mvoid sys_ipc_reg_call(void);[m
[32m+[m[32mvoid sys_ipc_return(void);[m
[32m+[m
 #define SYS_putc				0[m
 #define SYS_getc				1[m
 #define SYS_yield				2[m
[1mdiff --git a/kernel/tests/CMakeLists.txt b/kernel/tests/CMakeLists.txt[m
[1mnew file mode 100644[m
[1mindex 0000000..7dfd3f2[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/CMakeLists.txt[m
[36m@@ -0,0 +1,8 @@[m
[32m+[m[32mcmake_minimum_required(VERSION 3.14)[m
[32m+[m
[32m+[m[32mfile(GLOB OBJECT_SOURCE "*.c")[m
[32m+[m[32madd_library(${PROJECT_NAME}-tests OBJECT ${OBJECT_SOURCE})[m
[32m+[m[32mtarget_include_directories([m
[32m+[m	[32m${PROJECT_NAME}-tests[m
[32m+[m	[32mPUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include"[m
[32m+[m[32m)[m
[1mdiff --git a/kernel/tests/barrier.c b/kernel/tests/barrier.c[m
[1mnew file mode 100644[m
[1mindex 0000000..96f763c[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/barrier.c[m
[36m@@ -0,0 +1,68 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS),[m
[32m+[m[32m * Shanghai Jiao Tong University (SJTU) OS-Lab-2020 (i.e., ChCore) is licensed[m
[32m+[m[32m * under the Mulan PSL v1. You can use this software according to the terms and[m
[32m+[m[32m * conditions of the Mulan PSL v1. You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY[m
[32m+[m[32m * KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO[m
[32m+[m[32m * NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE. See the[m
[32m+[m[32m * Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/sync.h>[m
[32m+[m[32m#include <tests/barrier.h>[m
[32m+[m[32m#include <common/errno.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m
[32m+[m[32mvolatile u64 cpu_barrier[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32m#define PRIMARY_CPU_ID 0[m
[32m+[m
[32m+[m[32mvoid global_barrier_init(void)[m
[32m+[m[32m{[m
[32m+[m	[32mint i;[m
[32m+[m	[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m		[32mcpu_barrier[i] = 0;[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid global_barrier(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mif (is_bsp)[m
[32m+[m		[32mglobal_barrier_primary();[m
[32m+[m	[32melse[m
[32m+[m		[32mglobal_barrier_secondary();[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid global_barrier_primary(void)[m
[32m+[m[32m{[m
[32m+[m	[32mint i;[m
[32m+[m	[32mu32 cpu_id = smp_get_cpu_id();[m
[32m+[m	[32mu64 barrier_num;[m
[32m+[m
[32m+[m	[32mBUG_ON(PRIMARY_CPU_ID != cpu_id);[m
[32m+[m
[32m+[m	[32mbarrier_num = cpu_barrier[cpu_id];[m
[32m+[m	[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m		[32mif (i == cpu_id)[m
[32m+[m			[32mcontinue;[m
[32m+[m		[32mwhile (cpu_barrier[i] != barrier_num + 1) ;[m
[32m+[m	[32m}[m
[32m+[m	[32mcpu_barrier[cpu_id] = barrier_num + 1;[m
[32m+[m	[32masm volatile ("dsb sy");[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid global_barrier_secondary(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 cpu_id = smp_get_cpu_id();[m
[32m+[m	[32mu64 barrier_num;[m
[32m+[m
[32m+[m	[32mbarrier_num = cpu_barrier[cpu_id];[m
[32m+[m	[32mcpu_barrier[cpu_id]++;[m
[32m+[m	[32mwhile (cpu_barrier[PRIMARY_CPU_ID] != barrier_num + 1) ;[m
[32m+[m	[32masm volatile ("dsb sy");[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/tests/barrier.h b/kernel/tests/barrier.h[m
[1mnew file mode 100644[m
[1mindex 0000000..b55a682[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/barrier.h[m
[36m@@ -0,0 +1,22 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <common/types.h>[m
[32m+[m
[32m+[m[32mextern volatile u64 cpu_barrier[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32mvoid global_barrier_init(void);[m
[32m+[m[32mvoid global_barrier(bool);[m
[32m+[m[32mvoid global_barrier_primary(void);[m
[32m+[m[32mvoid global_barrier_secondary(void);[m
[1mdiff --git a/kernel/tests/tests.c b/kernel/tests/tests.c[m
[1mnew file mode 100644[m
[1mindex 0000000..e8035d7[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/tests.c[m
[36m@@ -0,0 +1,32 @@[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <tests/tests.h>[m
[32m+[m
[32m+[m[32mvoid init_test(void)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 ret = 0;[m
[32m+[m
[32m+[m	[32mglobal_barrier_init();[m
[32m+[m	[32mret = lock_init(&test_lock);[m
[32m+[m	[32mBUG_ON(ret != 0);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid run_test(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mif (is_bsp)[m
[32m+[m		[32mkinfo("[ChCore] kernel tests\n");[m
[32m+[m
[32m+[m	[32mtst_mutex(is_bsp);[m
[32m+[m	[32mtst_big_lock(is_bsp);[m
[32m+[m
[32m+[m	[32mtst_sched_cooperative(is_bsp);[m
[32m+[m	[32mtst_sched_preemptive(is_bsp);[m
[32m+[m	[32mtst_sched_affinity(is_bsp);[m
[32m+[m	[32mtst_sched(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mkinfo("[ChCore] pass all kernel tests\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/tests/tests.h b/kernel/tests/tests.h[m
[1mnew file mode 100644[m
[1mindex 0000000..0750983[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/tests.h[m
[36m@@ -0,0 +1,23 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <common/lock.h>[m
[32m+[m[32m#include <tests/barrier.h>[m
[32m+[m
[32m+[m[32mextern struct lock test_lock;[m
[32m+[m
[32m+[m[32mvoid init_test(void);[m
[32m+[m[32mvoid run_test(bool);[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Locking[m
[32m+[m[32m */[m
[32m+[m[32mvoid tst_mutex(bool);[m
[32m+[m[32mvoid tst_big_lock(bool);[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Scheduler[m
[32m+[m[32m */[m
[32m+[m[32mvoid tst_sched_cooperative(bool);[m
[32m+[m[32mvoid tst_sched_preemptive(bool);[m
[32m+[m[32mvoid tst_sched_affinity(bool);[m
[32m+[m[32mvoid tst_sched(bool);[m
[1mdiff --git a/kernel/tests/tst_mutex.c b/kernel/tests/tst_mutex.c[m
[1mnew file mode 100644[m
[1mindex 0000000..8153b55[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/tst_mutex.c[m
[36m@@ -0,0 +1,69 @@[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m
[32m+[m[32m#include <tests/tests.h>[m
[32m+[m
[32m+[m[32m#define LOCK_TEST_NUM 100000[m
[32m+[m
[32m+[m[32m/* Mutex test count */[m
[32m+[m[32mstruct lock test_lock;[m
[32m+[m[32munsigned long mutex_test_count = 0;[m
[32m+[m[32munsigned long big_lock_test_count = 0;[m
[32m+[m
[32m+[m[32mvoid tst_mutex(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32m/* Mutex Lock */[m
[32m+[m	[32mfor (int i = 0; i < LOCK_TEST_NUM; i++) {[m
[32m+[m		[32mif (i % 2)[m
[32m+[m			[32mwhile (try_lock(&test_lock) != 0) ;[m
[32m+[m		[32melse[m
[32m+[m			[32mlock(&test_lock);[m
[32m+[m		[32m/* Critical Section */[m
[32m+[m		[32mmutex_test_count++;[m
[32m+[m		[32munlock(&test_lock);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m	[32mBUG_ON(mutex_test_count != PLAT_CPU_NUM * LOCK_TEST_NUM);[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mprintk("pass tst_mutex\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_big_lock(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i;[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mbig_lock_test_count = 0;[m
[32m+[m		[32mBUG_ON(!is_locked(&big_kernel_lock));[m
[32m+[m		[32munlock_kernel();[m
[32m+[m	[32m}[m
[32m+[m	[32m// kinfo("CPU%u 1-1\n", cpu_id);[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mfor (i = 0; i < LOCK_TEST_NUM; ++i) {[m
[32m+[m		[32mif (i % 2)[m
[32m+[m			[32mwhile (try_lock(&big_kernel_lock) != 0) ;[m
[32m+[m		[32melse[m
[32m+[m			[32mlock_kernel();[m
[32m+[m		[32mbig_lock_test_count += 1;[m
[32m+[m		[32munlock_kernel();[m
[32m+[m		[32m// if (i % 100 == 1)[m
[32m+[m		[32m//      kinfo("pri:%d\n", i);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m// kinfo("CPU%u 1-2\n", cpu_id);[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m	[32mBUG_ON(LOCK_TEST_NUM * PLAT_CPU_NUM != big_lock_test_count);[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mlock_kernel();[m
[32m+[m		[32mprintk("pass tst_big_lock\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[1mdiff --git a/kernel/tests/tst_sched.c b/kernel/tests/tst_sched.c[m
[1mnew file mode 100644[m
[1mindex 0000000..57c61a8[m
[1m--- /dev/null[m
[1m+++ b/kernel/tests/tst_sched.c[m
[36m@@ -0,0 +1,537 @@[m
[32m+[m[32m#include <common/smp.h>[m
[32m+[m[32m#include <common/kprint.h>[m
[32m+[m[32m#include <common/macro.h>[m
[32m+[m[32m#include <common/kmalloc.h>[m
[32m+[m[32m#include <process/thread.h>[m
[32m+[m[32m#include <sched/context.h>[m
[32m+[m[32m#include <sched/sched.h>[m
[32m+[m[32m#include <tests/tests.h>[m
[32m+[m
[32m+[m[32m#define TEST_NUM 1[m
[32m+[m[32m#define THREAD_NUM 8[m
[32m+[m
[32m+[m[32mvolatile int sched_start_flag = 0;[m
[32m+[m[32mvolatile int sched_finish_flag = 0;[m
[32m+[m
[32m+[m[32mextern struct list_head rr_ready_queue[PLAT_CPU_NUM];[m
[32m+[m
[32m+[m[32mstatic void atomic_sched(void)[m
[32m+[m[32m{[m
[32m+[m	[32mlock(&test_lock);[m
[32m+[m	[32msched();[m
[32m+[m	[32munlock(&test_lock);[m
[32m+[m
[32m+[m	[32mBUG_ON(!current_thread);[m
[32m+[m	[32mBUG_ON(!current_thread->thread_ctx);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic int atomic_sched_enqueue(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m
[32m+[m	[32mlock(&test_lock);[m
[32m+[m	[32mret = sched_enqueue(thread);[m
[32m+[m	[32munlock(&test_lock);[m
[32m+[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic struct thread *atomic_sched_choose_thread(void)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct thread *ret = NULL;[m
[32m+[m
[32m+[m	[32mlock(&test_lock);[m
[32m+[m	[32mret = sched_choose_thread();[m
[32m+[m	[32munlock(&test_lock);[m
[32m+[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic struct thread *create_test_thread(int prio, int aff)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mstruct thread *thread = NULL;[m
[32m+[m
[32m+[m	[32mlock(&test_lock);[m
[32m+[m	[32mthread = kmalloc(sizeof(struct thread));[m
[32m+[m	[32mBUG_ON(!(thread->thread_ctx = create_thread_ctx()));[m
[32m+[m	[32munlock(&test_lock);[m
[32m+[m	[32minit_thread_ctx(thread, 0, 0, prio, TYPE_TESTS, aff);[m
[32m+[m	[32mfor (i = 0; i < REG_NUM; i++)[m
[32m+[m		[32mthread->thread_ctx->ec.reg[i] = prio;[m
[32m+[m
[32m+[m	[32mreturn thread;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic void check_thread_ctx(void)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mstruct thread_ctx *thread_ctx = NULL;[m
[32m+[m
[32m+[m	[32mlock(&test_lock);[m
[32m+[m	[32mthread_ctx = (struct thread_ctx *)switch_context();[m
[32m+[m	[32munlock(&test_lock);[m
[32m+[m	[32mfor (i = 0; i < REG_NUM; i++)[m
[32m+[m		[32mBUG_ON(thread_ctx->ec.reg[i] != thread_ctx->prio);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic void free_test_thread(struct thread *thread)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(thread->thread_ctx->type == TYPE_IDLE);[m
[32m+[m	[32mlock(&test_lock);[m
[32m+[m	[32mdestroy_thread_ctx(thread);[m
[32m+[m	[32mkfree(thread);[m
[32m+[m	[32munlock(&test_lock);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_param(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mu32 local_thread_num = 4;[m
[32m+[m	[32mu32 cpuid = smp_get_cpu_id();[m
[32m+[m	[32mstruct thread *threads[4];[m
[32m+[m	[32mstruct thread *idle_thread = NULL;[m
[32m+[m	[32mstruct thread *thread = NULL;[m
[32m+[m	[32mstruct thread_ctx *thread_ctx = NULL;[m
[32m+[m
[32m+[m	[32m/* Init threads */[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32mthreads[i] = create_test_thread(i, NO_AFF);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{			// test enqueue[m
[32m+[m		[32mBUG_ON(!sched_enqueue(NULL));[m
[32m+[m		[32m{[m
[32m+[m			[32mthread_ctx = threads[0]->thread_ctx;[m
[32m+[m			[32mthreads[0]->thread_ctx = NULL;[m
[32m+[m			[32mBUG_ON(!sched_enqueue(threads[0]));[m
[32m+[m			[32mthreads[0]->thread_ctx = thread_ctx;[m
[32m+[m
[32m+[m			[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m		[32m}[m
[32m+[m		[32m{[m
[32m+[m			[32mthreads[0]->thread_ctx->state = TS_READY;[m
[32m+[m			[32mBUG_ON(!sched_enqueue(threads[0]));[m
[32m+[m			[32mthreads[0]->thread_ctx->state = TS_INIT;[m
[32m+[m		[32m}[m
[32m+[m		[32m{[m
[32m+[m			[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m				[32mBUG_ON(sched_enqueue(threads[i]));[m
[32m+[m				[32mBUG_ON(threads[i]->thread_ctx->cpuid != cpuid);[m
[32m+[m				[32mBUG_ON(threads[i]->thread_ctx->state !=[m
[32m+[m				[32m       TS_READY);[m
[32m+[m			[32m}[m
[32m+[m
[32m+[m			[32mBUG_ON(!sched_enqueue(threads[0]));[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{			// test dequeue[m
[32m+[m		[32mBUG_ON(!sched_dequeue(NULL));[m
[32m+[m		[32m{[m
[32m+[m			[32mthread_ctx = threads[0]->thread_ctx;[m
[32m+[m			[32mthreads[0]->thread_ctx = NULL;[m
[32m+[m			[32mBUG_ON(!sched_dequeue(threads[0]));[m
[32m+[m			[32mthreads[0]->thread_ctx = thread_ctx;[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32m{[m
[32m+[m			[32mBUG_ON(sched_dequeue(threads[2]));[m
[32m+[m			[32mBUG_ON(sched_dequeue(threads[1]));[m
[32m+[m			[32mBUG_ON(sched_dequeue(threads[3]));[m
[32m+[m			[32mBUG_ON(sched_dequeue(threads[0]));[m
[32m+[m
[32m+[m			[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m				[32mBUG_ON(threads[i]->thread_ctx->state !=[m
[32m+[m				[32m       TS_INTER);[m
[32m+[m			[32m}[m
[32m+[m
[32m+[m			[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{			// test choose_thread & idle thread[m
[32m+[m		[32midle_thread = sched_choose_thread();[m
[32m+[m		[32mBUG_ON(idle_thread->thread_ctx->type != TYPE_IDLE);[m
[32m+[m
[32m+[m		[32m{[m
[32m+[m			[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m			[32mBUG_ON(sched_enqueue(idle_thread));[m
[32m+[m			[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32m{[m
[32m+[m			[32mBUG_ON(sched_enqueue(threads[0]));[m
[32m+[m			[32mBUG_ON(!sched_dequeue(idle_thread));[m
[32m+[m
[32m+[m			[32mthread = sched_choose_thread();[m
[32m+[m			[32mBUG_ON(thread != threads[0]);[m
[32m+[m
[32m+[m			[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32m{[m
[32m+[m			[32mBUG_ON(sched_enqueue(threads[3]));[m
[32m+[m			[32mBUG_ON(sched_enqueue(threads[2]));[m
[32m+[m			[32mBUG_ON(sched_enqueue(threads[0]));[m
[32m+[m			[32mBUG_ON(sched_enqueue(threads[1]));[m
[32m+[m
[32m+[m			[32mthread = sched_choose_thread();[m
[32m+[m			[32mBUG_ON(thread != threads[3]);[m
[32m+[m
[32m+[m			[32mBUG_ON(sched_dequeue(threads[2]));[m
[32m+[m			[32mBUG_ON(sched_dequeue(threads[1]));[m
[32m+[m
[32m+[m			[32mthread = sched_choose_thread();[m
[32m+[m			[32mBUG_ON(thread != threads[0]);[m
[32m+[m
[32m+[m			[32mthread = sched_choose_thread();[m
[32m+[m			[32mBUG_ON(thread != idle_thread);[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{			// test sched[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[3]));[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[2]));[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[0]));[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[1]));[m
[32m+[m
[32m+[m		[32msched();[m
[32m+[m		[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m		[32mBUG_ON(threads[3]->thread_ctx->state != TS_RUNNING);[m
[32m+[m		[32mBUG_ON(!sched_dequeue(threads[3]));[m
[32m+[m
[32m+[m		[32mthread = sched_choose_thread();[m
[32m+[m		[32mBUG_ON(thread != threads[2]);[m
[32m+[m
[32m+[m		[32msched();[m
[32m+[m		[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m		[32mBUG_ON(threads[0]->thread_ctx->state != TS_RUNNING);[m
[32m+[m		[32mBUG_ON(!sched_dequeue(threads[0]));[m
[32m+[m
[32m+[m		[32mthread = sched_choose_thread();[m
[32m+[m		[32mBUG_ON(thread != threads[1]);[m
[32m+[m
[32m+[m		[32msched();[m
[32m+[m		[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m		[32mBUG_ON(threads[3]->thread_ctx->state != TS_RUNNING);[m
[32m+[m		[32mBUG_ON(!sched_dequeue(threads[3]));[m
[32m+[m
[32m+[m		[32mthread = sched_choose_thread();[m
[32m+[m		[32mBUG_ON(thread != threads[0]);[m
[32m+[m
[32m+[m		[32mBUG_ON(current_thread != threads[3]);[m
[32m+[m		[32mcurrent_thread = NULL;[m
[32m+[m
[32m+[m		[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32mfree_test_thread(threads[i]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_queue(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mstruct thread *threads[THREAD_NUM];[m
[32m+[m
[32m+[m	[32m/* Init threads */[m
[32m+[m	[32mfor (i = 0; i < THREAD_NUM; i++) {[m
[32m+[m		[32mthreads[i] = create_test_thread(i, NO_AFF);[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[i]));[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mfor (i = 0; i < THREAD_NUM; i++) {[m
[32m+[m		[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(current_thread != threads[i]);[m
[32m+[m		[32mcheck_thread_ctx();[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mfor (i = 0; i < THREAD_NUM; i++) {[m
[32m+[m		[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(current_thread != threads[i]);[m
[32m+[m		[32mfree_test_thread(current_thread);[m
[32m+[m		[32mcurrent_thread = NULL;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_cooperative(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mtst_sched_param(is_bsp);[m
[32m+[m	[32mtst_sched_queue(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mprintk("pass tst_sched_cooperative\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_budget(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mu32 local_thread_num = 4;[m
[32m+[m	[32mstruct thread *threads[4];[m
[32m+[m
[32m+[m	[32m/* Init threads */[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32mthreads[i] = create_test_thread(i, NO_AFF);[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[i]));[m
[32m+[m	[32m}[m
[32m+[m	[32mBUG_ON(current_thread);[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32msched();[m
[32m+[m	[32mBUG_ON(!current_thread->thread_ctx->sc);[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(current_thread != threads[0]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m	[32msched();[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(current_thread != threads[1]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(!current_thread->thread_ctx->sc);[m
[32m+[m		[32mBUG_ON(current_thread != threads[(i + 2) % PLAT_CPU_NUM]);[m
[32m+[m		[32mfree_test_thread(threads[(i + 2) % PLAT_CPU_NUM]);[m
[32m+[m		[32mcurrent_thread = NULL;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_timer(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0, j = 0;[m
[32m+[m	[32mu32 local_thread_num = 4;[m
[32m+[m	[32mstruct thread *threads[4];[m
[32m+[m
[32m+[m	[32m/* Init threads */[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32mthreads[i] = create_test_thread(i, NO_AFF);[m
[32m+[m		[32mBUG_ON(sched_enqueue(threads[i]));[m
[32m+[m	[32m}[m
[32m+[m	[32mBUG_ON(current_thread);[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mfor (j = 0; j < DEFAULT_BUDGET; j++) {[m
[32m+[m		[32msched_handle_timer_irq();[m
[32m+[m	[32m}[m
[32m+[m	[32msched();[m
[32m+[m	[32mBUG_ON(!current_thread->thread_ctx->sc);[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(current_thread != threads[0]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mthreads[0]->thread_ctx->sc->budget = 0;[m
[32m+[m	[32mfor (j = 0; j < DEFAULT_BUDGET; j++) {[m
[32m+[m		[32msched_handle_timer_irq();[m
[32m+[m	[32m}[m
[32m+[m	[32msched();[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(current_thread != threads[1]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mBUG_ON(DEFAULT_BUDGET <= 1);[m
[32m+[m	[32msched_handle_timer_irq();[m
[32m+[m	[32msched();[m
[32m+[m	[32mBUG_ON(current_thread != threads[1]);[m
[32m+[m
[32m+[m	[32mfor (j = 0; j < DEFAULT_BUDGET; j++) {[m
[32m+[m		[32msched_handle_timer_irq();[m
[32m+[m	[32m}[m
[32m+[m	[32mfor (i = 0; i < local_thread_num; i++) {[m
[32m+[m		[32msched();[m
[32m+[m		[32mBUG_ON(!current_thread->thread_ctx->sc);[m
[32m+[m		[32mBUG_ON(current_thread != threads[(i + 2) % PLAT_CPU_NUM]);[m
[32m+[m		[32mfree_test_thread(threads[(i + 2) % PLAT_CPU_NUM]);[m
[32m+[m		[32mcurrent_thread = NULL;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_preemptive(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mtst_sched_budget(is_bsp);[m
[32m+[m	[32mtst_sched_timer(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mprintk("pass tst_sched_preemptive\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_aff_param(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 cpuid = smp_get_cpu_id();[m
[32m+[m	[32mstruct thread *thread = NULL, *idle_thread = NULL;[m
[32m+[m
[32m+[m	[32m/* should return idle thread */[m
[32m+[m	[32mthread = atomic_sched_choose_thread();[m
[32m+[m	[32mBUG_ON(thread->thread_ctx->type != TYPE_IDLE);[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mthread = create_test_thread(0, 6);[m
[32m+[m	[32mBUG_ON(!sched_enqueue(thread));[m
[32m+[m
[32m+[m	[32mBUG_ON(!sched_dequeue(thread));[m
[32m+[m
[32m+[m	[32midle_thread = sched_choose_thread();[m
[32m+[m	[32mBUG_ON(idle_thread->thread_ctx->type != TYPE_IDLE);[m
[32m+[m
[32m+[m	[32mfree_test_thread(thread);[m
[32m+[m	[32mBUG_ON(!list_empty(&rr_ready_queue[cpuid]));[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_aff(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mu32 cpuid = smp_get_cpu_id();[m
[32m+[m	[32mstruct thread *thread = NULL;[m
[32m+[m	[32mstruct thread *threads[THREAD_NUM + 1];[m
[32m+[m
[32m+[m	[32m/* should return idle thread */[m
[32m+[m	[32mthread = atomic_sched_choose_thread();[m
[32m+[m	[32mBUG_ON(thread->thread_ctx->type != TYPE_IDLE);[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mfor (i = 0; i < THREAD_NUM + 1; i++) {[m
[32m+[m			[32mthreads[i] = create_test_thread(i, cpuid);[m
[32m+[m			[32mBUG_ON(sched_enqueue(threads[i]));[m
[32m+[m		[32m}[m
[32m+[m		[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m			[32mif (i != cpuid)[m
[32m+[m				[32mBUG_ON(!list_empty(&rr_ready_queue[i]));[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mthreads[0]->thread_ctx->sc->budget = 0;[m
[32m+[m		[32msched();[m
[32m+[m		[32mfor (i = 0; i < THREAD_NUM + 1; i++) {[m
[32m+[m			[32mthreads[i]->thread_ctx->affinity = i % PLAT_CPU_NUM;[m
[32m+[m			[32mthreads[i]->thread_ctx->sc->budget = 0;[m
[32m+[m			[32msched();[m
[32m+[m		[32m}[m
[32m+[m		[32mfor (i = 0; i < THREAD_NUM / PLAT_CPU_NUM; i++) {[m
[32m+[m			[32mthreads[i * PLAT_CPU_NUM]->thread_ctx->sc->budget = 0;[m
[32m+[m			[32msched();[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m	[32mfor (i = 0; i < THREAD_NUM / PLAT_CPU_NUM; i++) {[m
[32m+[m		[32mthread = atomic_sched_choose_thread();[m
[32m+[m		[32mBUG_ON(thread->thread_ctx->cpuid != cpuid);[m
[32m+[m		[32mBUG_ON(thread->thread_ctx->affinity % PLAT_CPU_NUM != cpuid);[m
[32m+[m		[32mBUG_ON(thread->thread_ctx->prio != i * PLAT_CPU_NUM + cpuid);[m
[32m+[m		[32mcurrent_thread = NULL;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mfor (i = 0; i < THREAD_NUM + 1; i++) {[m
[32m+[m			[32mfree_test_thread(threads[i]);[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched_affinity(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mtst_sched_aff_param(is_bsp);[m
[32m+[m	[32mtst_sched_aff(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mprintk("pass tst_sched_affinity\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid tst_sched(bool is_bsp)[m
[32m+[m[32m{[m
[32m+[m	[32mint i = 0, j = 0, k = 0;[m
[32m+[m	[32mu32 cpuid = smp_get_cpu_id();[m
[32m+[m	[32mstruct thread *thread = NULL;[m
[32m+[m
[32m+[m	[32m/* should return idle thread */[m
[32m+[m	[32mthread = atomic_sched_choose_thread();[m
[32m+[m	[32mBUG_ON(thread->thread_ctx->type != TYPE_IDLE);[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32m/* Init threads */[m
[32m+[m	[32mfor (i = 0; i < PLAT_CPU_NUM; i++) {[m
[32m+[m		[32mfor (j = 0; j < THREAD_NUM; j++) {[m
[32m+[m			[32mthread = create_test_thread(k, i);[m
[32m+[m			[32mBUG_ON(atomic_sched_enqueue(thread));[m
[32m+[m			[32mk++;[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mfor (j = 0; j < TEST_NUM; j++) {[m
[32m+[m		[32m/* Each core try to get those threads */[m
[32m+[m		[32mfor (i = 0; i < THREAD_NUM * PLAT_CPU_NUM; i++) {[m
[32m+[m			[32m/* get thread and dequeue from ready queue */[m
[32m+[m			[32mdo {[m
[32m+[m				[32m/* do it again if choose idle thread */[m
[32m+[m				[32matomic_sched();[m
[32m+[m				[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m			[32m} while (current_thread->thread_ctx->type == TYPE_IDLE);[m
[32m+[m			[32mBUG_ON(!current_thread->thread_ctx->sc);[m
[32m+[m			[32m/* Current thread set affinitiy */[m
[32m+[m			[32mcurrent_thread->thread_ctx->affinity =[m
[32m+[m			[32m    (i + cpuid) % PLAT_CPU_NUM;[m
[32m+[m			[32mcheck_thread_ctx();[m
[32m+[m		[32m}[m
[32m+[m		[32mif (smp_get_cpu_id() == 0) {[m
[32m+[m			[32mprintk(".");[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mfor (i = 0; i < THREAD_NUM * PLAT_CPU_NUM; i++) {[m
[32m+[m		[32m/* get thread and dequeue from ready queue */[m
[32m+[m		[32mdo {[m
[32m+[m			[32m/* do it again if choose idle thread */[m
[32m+[m			[32matomic_sched();[m
[32m+[m			[32mcurrent_thread->thread_ctx->sc->budget = 0;[m
[32m+[m		[32m} while (current_thread->thread_ctx->type == TYPE_IDLE);[m
[32m+[m		[32mBUG_ON(!current_thread->thread_ctx->sc);[m
[32m+[m		[32mfree_test_thread(current_thread);[m
[32m+[m		[32mcurrent_thread = NULL;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32m/* should return idle thread */[m
[32m+[m	[32mthread = atomic_sched_choose_thread();[m
[32m+[m	[32mBUG_ON(thread->thread_ctx->type != TYPE_IDLE);[m
[32m+[m
[32m+[m	[32mglobal_barrier(is_bsp);[m
[32m+[m
[32m+[m	[32mif (is_bsp) {[m
[32m+[m		[32mprintk("pass tst_sched\n");[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[1mdiff --git a/scripts/compile_user.sh b/scripts/compile_user.sh[m
[1mindex e37ceb8..4b96e24 100755[m
[1m--- a/scripts/compile_user.sh[m
[1m+++ b/scripts/compile_user.sh[m
[36m@@ -22,7 +22,8 @@[m [mecho "building ramdisk ..."[m
 [m
 mkdir -p ramdisk[m
 echo "copy user/*.bin to ramdisk."[m
[31m-cp lab3/*.bin ramdisk/[m
[32m+[m[32m#cp lab3/*.bin ramdisk/[m
[32m+[m[32mcp lab4/*.bin ramdisk/[m
 [m
 cd ramdisk[m
 find . | cpio -o -Hnewc > ../ramdisk.cpio[m
[1mdiff --git a/scripts/grade-lab4 b/scripts/grade-lab4[m
[1mnew file mode 100755[m
[1mindex 0000000..56cd717[m
[1m--- /dev/null[m
[1m+++ b/scripts/grade-lab4[m
[36m@@ -0,0 +1,193 @@[m
[32m+[m[32m#!/usr/bin/env python3[m
[32m+[m
[32m+[m[32mimport re[m
[32m+[m[32mfrom gradelib import *[m
[32m+[m
[32m+[m[32mr = Runner(save("chcore.out"),[m
[32m+[m[32m           stop_breakpoint("break_point"))[m
[32m+[m
[32m+[m[32m@test(0, "running chcore")[m
[32m+[m[32mdef test_chcore():[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_chcore)[m
[32m+[m[32mdef test_smp():[m
[32m+[m[32m    line = r.match("\[INFO\] AP 1 is activated!")[m
[32m+[m[32m    line = r.match_line(line, "\[INFO\] AP 2 is activated!")[m
[32m+[m[32m    line = r.match_line(line, "\[INFO\] AP 3 is activated!")[m
[32m+[m[32m    r.match_line(line, "\[INFO\] All 4 CPUs are active")[m
[32m+[m
[32m+[m[32m@test(5, parent=test_chcore)[m
[32m+[m[32mdef test_mutex():[m
[32m+[m[32m    r.match("pass tst_mutex")[m
[32m+[m
[32m+[m[32m@test(5, parent=test_chcore)[m
[32m+[m[32mdef test_big_lock():[m
[32m+[m[32m    r.match("pass tst_big_lock")[m
[32m+[m
[32m+[m[32m@test(10, parent=test_chcore)[m
[32m+[m[32mdef test_cooperative():[m
[32m+[m[32m    r.match("pass tst_sched_cooperative")[m
[32m+[m
[32m+[m[32m@test(5, parent=test_chcore)[m
[32m+[m[32mdef test_preemptive():[m
[32m+[m[32m    r.match("pass tst_sched_preemptive")[m
[32m+[m
[32m+[m[32m@test(5, parent=test_chcore)[m
[32m+[m[32mdef test_affinity():[m
[32m+[m[32m    r.match("pass tst_sched_affinity")[m
[32m+[m
[32m+[m[32m@test(5, parent=test_chcore)[m
[32m+[m[32mdef test_sched():[m
[32m+[m[32m    r.match("pass tst_sched")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_sched)[m
[32m+[m[32mdef test_yield_single():[m
[32m+[m[32m    r.make_kernel("yield_single")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_yield_single)[m
[32m+[m[32mdef test_yield_single_output():[m
[32m+[m[32m    line = r.match("Hello, I am thread 0")[m
[32m+[m[32m    line = r.match_line(line,"Hello, I am thread 1")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 1, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 1, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 2, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 2, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 3, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 3, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 4, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 4, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 5, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 5, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 6, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 6, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 7, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 7, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 8, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 8, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 9, thread 0, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 9, thread 1, cpu 0")[m
[32m+[m[32m    line = r.match_line(line,"Iteration 10, thread 0, cpu 0")[m
[32m+[m[32m    r.match_line(line,"Iteration 10, thread 1, cpu 0")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_yield_single_output)[m
[32m+[m[32mdef test_yield_spin():[m
[32m+[m[32m    r.make_kernel("yield_spin")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_yield_spin)[m
[32m+[m[32mdef test_yield_spin_output():[m
[32m+[m[32m    r.match("Successfully regain the control!")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_yield_spin_output)[m
[32m+[m[32mdef test_yield_multi():[m
[32m+[m[32m    r.make_kernel("yield_multi")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_yield_multi)[m
[32m+[m[32mdef test_yield_multi_output():[m
[32m+[m[32m    line = r.match("Hello, I am thread 0 on cpu 0")[m
[32m+[m[32m    line = r.match_line(line, "Hello, I am thread 1 on cpu 1")[m
[32m+[m[32m    line = r.match_line(line, "Hello, I am thread 2 on cpu 2")[m
[32m+[m[32m    r.match_line(line, "Hello, I am thread 3 on cpu 3")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_yield_multi_output)[m
[32m+[m[32mdef test_yield_aff():[m
[32m+[m[32m    r.make_kernel("yield_aff")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_yield_aff)[m
[32m+[m[32mdef test_yield_aff_output():[m
[32m+[m[32m    line = r.match("Main thread on cpu 0")[m
[32m+[m[32m    line = r.match_line(line, "Main thread set affinity 3")[m
[32m+[m[32m    line = r.match_line(line, "Main thread affinity 3")[m
[32m+[m[32m    r.match_line(line, "Main thread exits on cpu_id: 3")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_yield_aff_output)[m
[32m+[m[32mdef test_yield_multi_aff():[m
[32m+[m[32m    r.make_kernel("yield_multi_aff")[m
[32m+[m[32m    r.run_qemu(20)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_yield_multi_aff)[m
[32m+[m[32mdef test_yield_multi_aff_output():[m
[32m+[m[32m    line = r.match("Iteration 1, thread 0, cpu 0, aff 0")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 1, thread 1, cpu 1, aff 1")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 1, thread 2, cpu 2, aff 2")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 1, thread 3, cpu 1, aff 1")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 2, thread 0, cpu 2, aff 2")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 2, thread 1, cpu 3, aff 3")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 2, thread 2, cpu 0, aff 0")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 2, thread 3, cpu 2, aff 2")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 3, thread 0, cpu 3, aff 3")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 3, thread 1, cpu 0, aff 0")[m
[32m+[m[32m    line = r.match_line(line, "Iteration 3, thread 2, cpu 1, aff 1")[m
[32m+[m[32m    r.match_line(line, "Iteration 3, thread 3, cpu 3, aff 3")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_yield_multi_aff_output)[m
[32m+[m[32mdef test_spawn_basic():[m
[32m+[m[32m    r.make_kernel("spawn_basic")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(10, parent=test_spawn_basic)[m
[32m+[m[32mdef test_spawn_basic_output():[m
[32m+[m[32m    line = r.match("\[Child\] Child on cpu 1")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] argv: 0x800f008, argv\[0\]: 0x800ffc0")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] info_page_addr: 0x0")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] transfered_cap: 0")[m
[32m+[m[32m    r.match_line(line, "\[Child\] Bye")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_spawn_basic_output)[m
[32m+[m[32mdef test_spawn_info():[m
[32m+[m[32m    r.make_kernel("spawn_info")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_spawn_info)[m
[32m+[m[32mdef test_spawn_info_output():[m
[32m+[m[32m    line = r.match("\[Child\] Child on cpu 2")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] argv: 0x800f008, argv\[0\]: 0x800ffc0")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] info_page_addr: 0x100000000")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] The spawn\(\) seems ok\?")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] Uif!tqbxo\)\*!tffnt!pl@")[m
[32m+[m[32m    line = r.match_line(line, "\[Child\] Bye")[m
[32m+[m[32m    line = r.match_line(line, "\[Parent\] Are you ok\.\.\.")[m
[32m+[m[32m    r.match_line(line, "\[Parent\] Bye")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_spawn_info_output)[m
[32m+[m[32mdef test_ipc_data():[m
[32m+[m[32m    r.make_kernel("ipc_data")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(10, parent=test_ipc_data)[m
[32m+[m[32mdef test_ipc_data_output():[m
[32m+[m[32m    line = r.match("\[Parent\] create the server process\.")[m
[32m+[m[32m    line = r.match_line(line, "\[Client\] Return 4950!")[m
[32m+[m[32m    line = r.match_line(line, "\[Client\] exit")[m
[32m+[m[32m    r.match_line(line, "\[Server\] exit")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_ipc_data_output)[m
[32m+[m[32mdef test_ipc_mem():[m
[32m+[m[32m    r.make_kernel("ipc_mem")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_ipc_mem)[m
[32m+[m[32mdef test_ipc_mem_output():[m
[32m+[m[32m    line = r.match("\[Parent\] create the server process\.")[m
[32m+[m[32m    line = r.match_line(line, "\[Server\] read deadbeef")[m
[32m+[m[32m    line = r.match_line(line, "\[Client\] exit")[m
[32m+[m[32m    r.match_line(line, "\[Server\] exit")[m
[32m+[m
[32m+[m[32m@test(0, parent=test_ipc_mem_output)[m
[32m+[m[32mdef test_ipc_reg():[m
[32m+[m[32m    r.make_kernel("ipc_reg")[m
[32m+[m[32m    r.run_qemu(10)[m
[32m+[m
[32m+[m[32m@test(5, parent=test_ipc_reg)[m
[32m+[m[32mdef test_ipc_reg_output():[m
[32m+[m[32m    line = r.match("\[Parent\] create the server process\.")[m
[32m+[m[32m    line = r.match_line(line, "\[Client\] Return 526!")[m
[32m+[m[32m    line = r.match_line(line, "\[Client\] exit")[m
[32m+[m[32m    r.match_line(line, "\[Server\] exit")[m
[32m+[m
[32m+[m
[32m+[m[32mrun_tests()[m
[1mdiff --git a/tests/mm/buddy/CMakeLists.txt b/tests/mm/buddy/CMakeLists.txt[m
[1mindex 8a58d64..27eb4f1 100644[m
[1m--- a/tests/mm/buddy/CMakeLists.txt[m
[1m+++ b/tests/mm/buddy/CMakeLists.txt[m
[36m@@ -18,6 +18,7 @@[m [minclude_directories([m
     ../../../kernel/mm/[m
     ../../../kernel/[m
     ../../include[m
[32m+[m[32m    ../../../[m
 )[m
 [m
 target_compile_options([m
[1mdiff --git a/tests/mm/buddy/test_buddy.c b/tests/mm/buddy/test_buddy.c[m
[1mindex 063ca05..c016e11 100644[m
[1m--- a/tests/mm/buddy/test_buddy.c[m
[1m+++ b/tests/mm/buddy/test_buddy.c[m
[36m@@ -63,6 +63,10 @@[m [mstatic void test_alloc(struct phys_mem_pool *zone, long n, long order)[m
 	for (i = 0; i < n; ++i) {[m
 		page = buddy_get_pages(zone, order);[m
 		mu_check(page != NULL);[m
[32m+[m		[32m// for(int i=0;i < BUDDY_MAX_ORDER;i++){[m
[32m+[m		[32m// 	printf("order %d : %lld \n", i, global_mem.free_lists[i].nr_free);[m
[32m+[m		[32m// }[m
[32m+[m		[32m// mu_check(global_mem.free_lists[BUDDY_MAX_ORDER-1].nr_free == 1);[m
 		get_page_idx(zone, page);[m
 	}[m
 	return;[m
[36m@@ -99,15 +103,22 @@[m [mvoid test_buddy(void)[m
 	/* check the init state */[m
 	nget = buddy_num_free_page(&global_mem);[m
 	ncheck = npages / powl(2, BUDDY_MAX_ORDER - 1);[m
[31m-	//printf("ncheck is %ld\n", ncheck);[m
[31m-	mu_check(nget == ncheck);[m
[32m+[m	[32mmu_check(nget == ncheck); // nget = ncheck = free_lists[BUDDY_MAX_ORDER-1].nr_free = 64[m
[32m+[m	[32m// for(int i=0;i < BUDDY_MAX_ORDER;i++){[m
[32m+[m	[32m// 	printf("order %d : %lld \n", i, global_mem.free_lists[i].nr_free);[m
[32m+[m	[32m// }[m
[32m+[m	[32m// mu_check(global_mem.free_lists[BUDDY_MAX_ORDER-1].nr_free == 1);[m
 [m
 	/* alloc single page for $npages times */[m
 	test_alloc(&global_mem, npages, 0);[m
 [m
 	/* should have 0 free pages */[m
[31m-	nget = buddy_num_free_page(&global_mem);[m
[32m+[m	[32mnget = buddy_num_free_page(&global_mem); //nget=28[m
 	ncheck = 0;[m
[32m+[m	[32m// for(int i=0;i < BUDDY_MAX_ORDER;i++){[m
[32m+[m	[32m// 	printf("order %d : %lld \n", i, global_mem.free_lists[i].nr_free);[m
[32m+[m	[32m// }[m
[32m+[m	[32mprintf("\n nget:%ld, ncheck:%ld ", nget, ncheck);[m
 	mu_check(nget == ncheck);[m
 [m
 	/* free all pages */[m
[1mdiff --git a/tests/mm/page_table/CMakeLists.txt b/tests/mm/page_table/CMakeLists.txt[m
[1mindex ed02d09..6353062 100644[m
[1m--- a/tests/mm/page_table/CMakeLists.txt[m
[1m+++ b/tests/mm/page_table/CMakeLists.txt[m
[36m@@ -14,6 +14,7 @@[m [minclude_directories([m
     ../../../kernel/mm[m
     ../../../kernel/[m
     ../../include[m
[32m+[m[32m    ../../../[m
 )[m
 [m
 add_custom_target([m
[1mdiff --git a/tests/mm/page_table/test_aarch64_page_table.c b/tests/mm/page_table/test_aarch64_page_table.c[m
[1mindex 69a5150..541631a 100644[m
[1m--- a/tests/mm/page_table/test_aarch64_page_table.c[m
[1m+++ b/tests/mm/page_table/test_aarch64_page_table.c[m
[36m@@ -7,6 +7,7 @@[m
 #undef PAGE_SIZE[m
 [m
 #include <common/mmu.h>[m
[32m+[m[32m// #include <common/mm.h>[m
 [m
 #undef phys_to_virt[m
 #undef virt_to_phys[m
[36m@@ -207,5 +208,12 @@[m [mint main(int argc, char *argv[])[m
 {[m
 	MU_RUN_SUITE(test_suite);[m
 	MU_REPORT();[m
[32m+[m
[32m+[m	[32m// /* check kernel space map*/[m
[32m+[m	[32m// vaddr_t va = KBASE + (128 << 21);[m
[32m+[m	[32m// paddr_t pa = (128 << 21);[m
[32m+[m	[32m// size_t len = (128 << 21);[m
[32m+[m	[32m// map_kernel_space(va, pa, len);[m
[32m+[m	[32m// kernel_space_check();[m
 	return minunit_status;[m
 }[m
[1mdiff --git a/user/CMakeLists.txt b/user/CMakeLists.txt[m
[1mindex 47e80c2..06f3919 100644[m
[1m--- a/user/CMakeLists.txt[m
[1m+++ b/user/CMakeLists.txt[m
[36m@@ -21,4 +21,5 @@[m [minclude_directories("..")[m
 [m
 add_subdirectory(lib)[m
 [m
[31m-add_subdirectory(lab3)[m
[32m+[m[32m# add_subdirectory(lab3)[m
[32m+[m[32madd_subdirectory(lab4)[m
[1mdiff --git a/user/lab4/CMakeLists.txt b/user/lab4/CMakeLists.txt[m
[1mnew file mode 100644[m
[1mindex 0000000..6f27a00[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/CMakeLists.txt[m
[36m@@ -0,0 +1,26 @@[m
[32m+[m[32mcmake_minimum_required(VERSION 3.11)[m
[32m+[m
[32m+[m[32mset(TEST_LAB4_BINS[m
[32m+[m[32m    "yield_single"[m
[32m+[m[32m    "yield_spin"[m
[32m+[m[32m    "yield_multi"[m
[32m+[m[32m    "yield_aff"[m
[32m+[m[32m    "yield_multi_aff"[m
[32m+[m[32m    "spawn_basic" "spawn_info" "spawn_child"[m
[32m+[m[32m    "ipc_data" "ipc_data_server"[m
[32m+[m[32m    "ipc_reg" "ipc_reg_server"[m
[32m+[m[32m     "ipc_mem" "ipc_mem_server"[m
[32m+[m[32m)[m
[32m+[m
[32m+[m[32mforeach(bin ${TEST_LAB4_BINS})[m
[32m+[m[32m  file(GLOB ${bin}_source_files "${bin}.c")[m
[32m+[m[32m  add_executable(${bin}.bin ${${bin}_source_files})[m
[32m+[m[32m  target_link_libraries(${bin}.bin chcore-user-lib)[m
[32m+[m[32m  set_property([m
[32m+[m[32m          TARGET ${bin}.bin[m
[32m+[m[32m          APPEND_STRING[m
[32m+[m[32m          PROPERTY[m
[32m+[m[32m          LINK_FLAGS[m
[32m+[m[32m          "-e START"[m
[32m+[m[32m  )[m
[32m+[m[32mendforeach(bin)[m
[1mdiff --git a/user/lab4/ipc_data.c b/user/lab4/ipc_data.c[m
[1mnew file mode 100644[m
[1mindex 0000000..6343e57[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/ipc_data.c[m
[36m@@ -0,0 +1,73 @@[m
[32m+[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/spawn.h>[m
[32m+[m
[32m+[m[32m#define CHILD_INFO_VADDR 0xb0000000	/* 2M */[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m	[32mint shared_page_pmo_cap;[m
[32m+[m	[32mint info_pmo_cap;[m
[32m+[m	[32mint new_process_cap, new_thread_cap;[m
[32m+[m	[32mipc_struct_t client_ipc_struct;[m
[32m+[m	[32mipc_msg_t *ipc_msg;[m
[32m+[m	[32mint i;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m	[32mstruct pmo_map_request pmo_map_reqs[1];[m
[32m+[m
[32m+[m	[32musys_fs_load_cpio(CPIO_BIN);[m
[32m+[m
[32m+[m	[32m/* create share memory */[m
[32m+[m	[32mshared_page_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(shared_page_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32m/* prepare the info_page (transfer init info) for the new process */[m
[32m+[m	[32minfo_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(info_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP, info_pmo_cap, CHILD_INFO_VADDR,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mfail_cond(ret < 0, "usys_map_pmo ret %d\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (void *)CHILD_INFO_VADDR;[m
[32m+[m	[32minfo_page->ready_flag = 0;[m
[32m+[m	[32minfo_page->exit_flag = 0;[m
[32m+[m	[32minfo_page->nr_args = 0;[m
[32m+[m
[32m+[m	[32mpmo_map_reqs[0].pmo_cap = info_pmo_cap;[m
[32m+[m	[32mpmo_map_reqs[0].addr = 0x100000000;[m
[32m+[m	[32mpmo_map_reqs[0].perm = VM_READ | VM_WRITE;[m
[32m+[m
[32m+[m	[32m/* create a new process */[m
[32m+[m	[32mprintf("[Parent] create the server process.\n");[m
[32m+[m
[32m+[m	[32mret = spawn("/ipc_data_server.bin", &new_process_cap, &new_thread_cap,[m
[32m+[m		[32m    pmo_map_reqs, 1, NULL, 0, 1);[m
[32m+[m	[32mfail_cond(ret < 0, "create_process returns %d\n", ret);[m
[32m+[m
[32m+[m	[32mwhile (info_page->ready_flag != 1)[m
[32m+[m		[32musys_yield();[m
[32m+[m
[32m+[m	[32m/* register IPC client */[m
[32m+[m	[32mret = ipc_register_client(new_thread_cap, &client_ipc_struct);[m
[32m+[m	[32mfail_cond(ret < 0, "ipc_register_client failed\n");[m
[32m+[m
[32m+[m	[32m/* IPC send cap */[m
[32m+[m	[32mipc_msg = ipc_create_msg(&client_ipc_struct, 4 * 100, 0);[m
[32m+[m	[32mfor (i = 0; i < 100; i++) {[m
[32m+[m		[32mipc_set_msg_data(ipc_msg, (char *)&i, i * 4, 4);[m
[32m+[m	[32m}[m
[32m+[m	[32mret = ipc_call(&client_ipc_struct, ipc_msg);[m
[32m+[m	[32mprintf("[Client] Return %d!\n", ret);[m
[32m+[m	[32mipc_destroy_msg(ipc_msg);[m
[32m+[m
[32m+[m	[32mprintf("[Client] exit\n");[m
[32m+[m	[32minfo_page->exit_flag = 1;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/ipc_data_server.c b/user/lab4/ipc_data_server.c[m
[1mnew file mode 100644[m
[1mindex 0000000..a025034[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/ipc_data_server.c[m
[36m@@ -0,0 +1,42 @@[m
[32m+[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m
[32m+[m[32mvoid ipc_dispatcher(ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m	[32mint i = 0;[m
[32m+[m	[32mint len = ipc_msg->data_len;[m
[32m+[m
[32m+[m	[32mwhile ((i * 4) < len) {[m
[32m+[m		[32mret += ((int *)ipc_get_msg_data(ipc_msg))[i];[m
[32m+[m		[32mi++;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mipc_return(ret);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mvoid *info_page_addr;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m
[32m+[m	[32minfo_page_addr = (void *)(envp[0]);[m
[32m+[m	[32mfail_cond(info_page_addr == NULL, "[Server] no info received.\n");[m
[32m+[m
[32m+[m	[32mret = ipc_register_server(ipc_dispatcher);[m
[32m+[m	[32mfail_cond(ret < 0, "[IPC Server] register server failed\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (struct info_page *)info_page_addr;[m
[32m+[m	[32minfo_page->ready_flag = 1;[m
[32m+[m
[32m+[m	[32mwhile (info_page->exit_flag != 1) {[m
[32m+[m		[32musys_yield();[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mprintf("[Server] exit\n");[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/ipc_mem.c b/user/lab4/ipc_mem.c[m
[1mnew file mode 100644[m
[1mindex 0000000..94ca5aa[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/ipc_mem.c[m
[36m@@ -0,0 +1,80 @@[m
[32m+[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/proc.h>[m
[32m+[m[32m#include <lib/spawn.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32m#define MAGIC_NUM 0xdeadbeef[m
[32m+[m[32m#define SHARED_PAGE_VADDR 0xa00000000[m
[32m+[m[32m#define CHILD_INFO_VADDR 0xb0000000	/* 2M */[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m	[32mint shared_page_pmo_cap;[m
[32m+[m	[32mint info_pmo_cap;[m
[32m+[m	[32mint new_process_cap, new_thread_cap;[m
[32m+[m	[32mipc_struct_t client_ipc_struct;[m
[32m+[m	[32mipc_msg_t *ipc_msg;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m	[32mstruct pmo_map_request pmo_map_reqs[1];[m
[32m+[m
[32m+[m	[32musys_fs_load_cpio(CPIO_BIN);[m
[32m+[m
[32m+[m	[32m/* prepare the info_page (transfer init info) for the new process */[m
[32m+[m	[32minfo_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(info_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP, info_pmo_cap, CHILD_INFO_VADDR,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mfail_cond(ret < 0, "usys_map_pmo ret %d\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (void *)CHILD_INFO_VADDR;[m
[32m+[m	[32minfo_page->ready_flag = 0;[m
[32m+[m	[32minfo_page->exit_flag = 0;[m
[32m+[m	[32minfo_page->nr_args = 0;[m
[32m+[m
[32m+[m	[32mpmo_map_reqs[0].pmo_cap = info_pmo_cap;[m
[32m+[m	[32mpmo_map_reqs[0].addr = 0x100000000;[m
[32m+[m	[32mpmo_map_reqs[0].perm = VM_READ | VM_WRITE;[m
[32m+[m
[32m+[m	[32m/* create a new process */[m
[32m+[m	[32mprintf("[Parent] create the server process.\n");[m
[32m+[m
[32m+[m	[32mret = spawn("/ipc_mem_server.bin", &new_process_cap, &new_thread_cap,[m
[32m+[m		[32m    pmo_map_reqs, 1, NULL, 0, 1);[m
[32m+[m	[32mfail_cond(ret < 0, "create_process returns %d\n", ret);[m
[32m+[m
[32m+[m	[32mwhile (info_page->ready_flag != 1)[m
[32m+[m		[32musys_yield();[m
[32m+[m
[32m+[m	[32m/* register IPC client */[m
[32m+[m	[32mret = ipc_register_client(new_thread_cap, &client_ipc_struct);[m
[32m+[m	[32mfail_cond(ret < 0, "ipc_register_client failed\n");[m
[32m+[m
[32m+[m	[32m/* create share memory */[m
[32m+[m	[32mshared_page_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(shared_page_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32m/* map shared memory */[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP, shared_page_pmo_cap, SHARED_PAGE_VADDR,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mfail_cond(ret < 0, "usys_map_pmo ret %d\n", ret);[m
[32m+[m
[32m+[m	[32m/* write shared memory */[m
[32m+[m	[32m*(int *)SHARED_PAGE_VADDR = MAGIC_NUM;[m
[32m+[m	[32m/* IPC send cap */[m
[32m+[m	[32mipc_msg = ipc_create_msg(&client_ipc_struct, 0, 1);[m
[32m+[m	[32mipc_set_msg_cap(ipc_msg, 0, shared_page_pmo_cap);[m
[32m+[m	[32mipc_call(&client_ipc_struct, ipc_msg);[m
[32m+[m	[32mipc_destroy_msg(ipc_msg);[m
[32m+[m
[32m+[m	[32mprintf("[Client] exit\n");[m
[32m+[m	[32minfo_page->exit_flag = 1;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/ipc_mem_server.c b/user/lab4/ipc_mem_server.c[m
[1mnew file mode 100644[m
[1mindex 0000000..b831af8[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/ipc_mem_server.c[m
[36m@@ -0,0 +1,51 @@[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m
[32m+[m[32m#define SHARED_PAGE_VADDR 0x20000000[m
[32m+[m
[32m+[m[32mvoid ipc_dispatcher(ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m
[32m+[m	[32mfail_cond(ipc_msg->data_len != 0, "data_len %lu\n", ipc_msg->data_len);[m
[32m+[m	[32mfail_cond(ipc_msg->cap_slot_number != 1, "cap_slot_number 5lu\n",[m
[32m+[m		[32m  ipc_msg->cap_slot_number);[m
[32m+[m	[32mint cap = ipc_get_msg_cap(ipc_msg, 0);[m
[32m+[m
[32m+[m	[32m/* map copied pmo to another va */[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP, cap, SHARED_PAGE_VADDR + PAGE_SIZE,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mfail_cond(ret < 0, "usys_map_pmo on copied pmo ret %d\n", ret);[m
[32m+[m
[32m+[m	[32m/* read from shared memory should be MAGIC_NUM */[m
[32m+[m	[32mprintf("[Server] read %x\n", *(int *)(SHARED_PAGE_VADDR + PAGE_SIZE));[m
[32m+[m	[32mret = 0;[m
[32m+[m
[32m+[m	[32mipc_return(ret);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mvoid *info_page_addr;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m
[32m+[m	[32minfo_page_addr = (void *)(envp[0]);[m
[32m+[m	[32mfail_cond(info_page_addr == NULL, "[Server] no info received.\n");[m
[32m+[m
[32m+[m	[32mret = ipc_register_server(ipc_dispatcher);[m
[32m+[m	[32mfail_cond(ret < 0, "[Server] register server failed\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (struct info_page *)info_page_addr;[m
[32m+[m	[32minfo_page->ready_flag = 1;[m
[32m+[m
[32m+[m	[32mwhile (info_page->exit_flag != 1) {[m
[32m+[m		[32musys_yield();[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mprintf("[Server] exit\n");[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/ipc_reg.c b/user/lab4/ipc_reg.c[m
[1mnew file mode 100644[m
[1mindex 0000000..a5ec471[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/ipc_reg.c[m
[36m@@ -0,0 +1,65 @@[m
[32m+[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/proc.h>[m
[32m+[m[32m#include <lib/spawn.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m
[32m+[m[32m#define CHILD_INFO_VADDR 0xb0000000	/* 2M */[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m	[32mint shared_page_pmo_cap;[m
[32m+[m	[32mint info_pmo_cap;[m
[32m+[m	[32mint new_process_cap, new_thread_cap;[m
[32m+[m	[32mipc_struct_t client_ipc_struct;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m	[32mstruct pmo_map_request pmo_map_reqs[1];[m
[32m+[m
[32m+[m	[32musys_fs_load_cpio(CPIO_BIN);[m
[32m+[m
[32m+[m	[32m/* create share memory */[m
[32m+[m	[32mshared_page_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(shared_page_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32m/* prepare the info_page (transfer init info) for the new process */[m
[32m+[m	[32minfo_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(info_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP, info_pmo_cap, CHILD_INFO_VADDR,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mfail_cond(ret < 0, "usys_map_pmo ret %d\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (void *)CHILD_INFO_VADDR;[m
[32m+[m	[32minfo_page->ready_flag = 0;[m
[32m+[m	[32minfo_page->exit_flag = 0;[m
[32m+[m	[32minfo_page->nr_args = 0;[m
[32m+[m
[32m+[m	[32mpmo_map_reqs[0].pmo_cap = info_pmo_cap;[m
[32m+[m	[32mpmo_map_reqs[0].addr = 0x100000000;[m
[32m+[m	[32mpmo_map_reqs[0].perm = VM_READ | VM_WRITE;[m
[32m+[m
[32m+[m	[32m/* create a new process */[m
[32m+[m	[32mprintf("[Parent] create the server process.\n");[m
[32m+[m
[32m+[m	[32mret = spawn("/ipc_reg_server.bin", &new_process_cap, &new_thread_cap,[m
[32m+[m		[32m    pmo_map_reqs, 1, NULL, 0, 1);[m
[32m+[m	[32mfail_cond(ret < 0, "create_process returns %d\n", ret);[m
[32m+[m
[32m+[m	[32mwhile (info_page->ready_flag != 1)[m
[32m+[m		[32musys_yield();[m
[32m+[m
[32m+[m	[32m/* register IPC client */[m
[32m+[m	[32mret = ipc_register_client(new_thread_cap, &client_ipc_struct);[m
[32m+[m	[32mfail_cond(ret < 0, "ipc_register_client failed\n");[m
[32m+[m
[32m+[m	[32mret = ipc_reg_call(&client_ipc_struct, (u64) 526);[m
[32m+[m	[32mprintf("[Client] Return %d!\n", ret);[m
[32m+[m
[32m+[m	[32mprintf("[Client] exit\n");[m
[32m+[m	[32minfo_page->exit_flag = 1;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/ipc_reg_server.c b/user/lab4/ipc_reg_server.c[m
[1mnew file mode 100644[m
[1mindex 0000000..2f44f26[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/ipc_reg_server.c[m
[36m@@ -0,0 +1,33 @@[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32mvoid ipc_dispatcher(ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mipc_return((u64) ipc_msg);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mvoid *info_page_addr;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m
[32m+[m	[32minfo_page_addr = (void *)(envp[0]);[m
[32m+[m	[32mfail_cond(info_page_addr == NULL, "[Server] no info received.\n");[m
[32m+[m
[32m+[m	[32mret = ipc_register_server(ipc_dispatcher);[m
[32m+[m	[32mfail_cond(ret < 0, "[IPC Server] register server failed\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (struct info_page *)info_page_addr;[m
[32m+[m	[32minfo_page->ready_flag = 1;[m
[32m+[m
[32m+[m	[32mwhile (info_page->exit_flag != 1) {[m
[32m+[m		[32musys_yield();[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mprintf("[Server] exit\n");[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/spawn_basic.c b/user/lab4/spawn_basic.c[m
[1mnew file mode 100644[m
[1mindex 0000000..93b50d0[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/spawn_basic.c[m
[36m@@ -0,0 +1,24 @@[m
[32m+[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/proc.h>[m
[32m+[m[32m#include <lib/spawn.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32m#define CHILD_INFO_VADDR 0xb0000000	/* 2M */[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m
[32m+[m	[32musys_fs_load_cpio(CPIO_BIN);[m
[32m+[m
[32m+[m	[32m/* create a new process */[m
[32m+[m	[32mprintf("[Parent] create the child process.\n");[m
[32m+[m
[32m+[m	[32mret = spawn("/spawn_child.bin", NULL, NULL, NULL, 0, NULL, 0, 1);[m
[32m+[m	[32mfail_cond(ret < 0, "create_process returns %d\n", ret);[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/spawn_child.c b/user/lab4/spawn_child.c[m
[1mnew file mode 100644[m
[1mindex 0000000..c52dc12[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/spawn_child.c[m
[36m@@ -0,0 +1,61 @@[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32m#define SHARED_PAGE_VADDR 0x20000000[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint i, ret;[m
[32m+[m	[32mint transfered_cap;[m
[32m+[m	[32mvoid *info_page_addr;[m
[32m+[m	[32mstruct info_page *info_page1, *info_page2;[m
[32m+[m
[32m+[m	[32mprintf("[Child] Child on cpu %u\n", usys_get_cpu_id());[m
[32m+[m	[32mprintf("[Child] argv: 0x%lx, argv[0]: 0x%lx\n", (u64) argv,[m
[32m+[m	[32m       (u64) argv[0]);[m
[32m+[m	[32minfo_page_addr = (void *)(envp[0]);[m
[32m+[m	[32mprintf("[Child] info_page_addr: 0x%lx\n", (u64) info_page_addr);[m
[32m+[m	[32mtransfered_cap = (int)((u64) envp[1]);[m
[32m+[m	[32mprintf("[Child] transfered_cap: %d\n", transfered_cap);[m
[32m+[m
[32m+[m	[32mif (info_page_addr) {[m
[32m+[m		[32minfo_page1 = (struct info_page *)info_page_addr;[m
[32m+[m		[32mprintf("[Child] ");[m
[32m+[m		[32mfor (i = 0; i < info_page1->nr_args - 1; i++) {[m
[32m+[m			[32mprintf("%c", (char)info_page1->args[i]);[m
[32m+[m			[32minfo_page1->args[i]++;[m
[32m+[m		[32m}[m
[32m+[m		[32mprintf("\n");[m
[32m+[m
[32m+[m		[32mret = usys_map_pmo(SELF_CAP, transfered_cap,[m
[32m+[m				[32m   SHARED_PAGE_VADDR + PAGE_SIZE,[m
[32m+[m				[32m   VM_READ | VM_WRITE);[m
[32m+[m		[32mfail_cond(ret < 0, "usys_map_pmo on copied pmo ret %d\n", ret);[m
[32m+[m
[32m+[m		[32minfo_page2 =[m
[32m+[m		[32m    (struct info_page *)(SHARED_PAGE_VADDR + PAGE_SIZE);[m
[32m+[m		[32mprintf("[Child] ");[m
[32m+[m		[32mfor (i = 0; i < info_page2->nr_args - 1; i++) {[m
[32m+[m			[32mprintf("%c", (char)info_page2->args[i]);[m
[32m+[m		[32m}[m
[32m+[m		[32mprintf("\n");[m
[32m+[m
[32m+[m		[32mret = usys_unmap_pmo(SELF_CAP, transfered_cap,[m
[32m+[m				[32m     SHARED_PAGE_VADDR + PAGE_SIZE);[m
[32m+[m		[32mfail_cond(ret < 0, "usys_unmap_pmo on copied pmo ret %d\n",[m
[32m+[m			[32m  ret);[m
[32m+[m
[32m+[m		[32mprintf("[Child] Bye\n");[m
[32m+[m		[32minfo_page1->ready_flag = 1;[m
[32m+[m
[32m+[m		[32mwhile (info_page1->exit_flag != 1) {[m
[32m+[m			[32musys_yield();[m
[32m+[m		[32m}[m
[32m+[m	[32m} else {[m
[32m+[m		[32mprintf("[Child] Bye\n");[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/spawn_info.c b/user/lab4/spawn_info.c[m
[1mnew file mode 100644[m
[1mindex 0000000..c4251c3[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/spawn_info.c[m
[36m@@ -0,0 +1,60 @@[m
[32m+[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/proc.h>[m
[32m+[m[32m#include <lib/spawn.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32m#define CHILD_INFO_VADDR 0xb0000000	/* 2M */[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[], char *envp[])[m
[32m+[m[32m{[m
[32m+[m	[32mint i, ret = 0;[m
[32m+[m	[32mint info_pmo_cap;[m
[32m+[m	[32mint new_process_cap, new_thread_cap;[m
[32m+[m	[32mstruct info_page *info_page;[m
[32m+[m	[32mstruct pmo_map_request pmo_map_reqs[1];[m
[32m+[m	[32mchar *msg = "The spawn() seems ok?";[m
[32m+[m
[32m+[m	[32musys_fs_load_cpio(CPIO_BIN);[m
[32m+[m
[32m+[m	[32m/* prepare the info_page (transfer init info) for the new process */[m
[32m+[m	[32minfo_pmo_cap = usys_create_pmo(PAGE_SIZE, PMO_DATA);[m
[32m+[m	[32mfail_cond(info_pmo_cap < 0, "usys_create_ret ret %d\n", ret);[m
[32m+[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP, info_pmo_cap, CHILD_INFO_VADDR,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mfail_cond(ret < 0, "usys_map_pmo ret %d\n", ret);[m
[32m+[m
[32m+[m	[32minfo_page = (void *)CHILD_INFO_VADDR;[m
[32m+[m	[32minfo_page->ready_flag = 0;[m
[32m+[m	[32minfo_page->exit_flag = 0;[m
[32m+[m	[32minfo_page->nr_args = 22;[m
[32m+[m	[32mfor (i = 0; i < info_page->nr_args; i++) {[m
[32m+[m		[32minfo_page->args[i] = (u64) (msg[i]);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mpmo_map_reqs[0].pmo_cap = info_pmo_cap;[m
[32m+[m	[32mpmo_map_reqs[0].addr = 0x100000000;[m
[32m+[m	[32mpmo_map_reqs[0].perm = VM_READ | VM_WRITE;[m
[32m+[m
[32m+[m	[32m/* create a new process */[m
[32m+[m
[32m+[m	[32mret = spawn("/spawn_child.bin", &new_process_cap, &new_thread_cap,[m
[32m+[m		[32m    pmo_map_reqs, 1, &info_pmo_cap, 1, 2);[m
[32m+[m	[32mfail_cond(ret < 0, "create_process returns %d\n", ret);[m
[32m+[m
[32m+[m	[32mprintf("[Parent] create the child process with cap %d.\n",[m
[32m+[m	[32m       new_process_cap);[m
[32m+[m
[32m+[m	[32mwhile (info_page->ready_flag != 1)[m
[32m+[m		[32musys_yield();[m
[32m+[m
[32m+[m	[32mprintf("[Parent] Are you ok...\n");[m
[32m+[m	[32mprintf("[Parent] Bye\n");[m
[32m+[m
[32m+[m	[32minfo_page->exit_flag = 1;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/yield_aff.c b/user/lab4/yield_aff.c[m
[1mnew file mode 100644[m
[1mindex 0000000..07cd95e[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/yield_aff.c[m
[36m@@ -0,0 +1,26 @@[m
[32m+[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m
[32m+[m[32mint main()[m
[32m+[m[32m{[m
[32m+[m	[32mint ret = 0;[m
[32m+[m	[32mint aff = 3;[m
[32m+[m
[32m+[m	[32mprintf("Main thread on cpu %u\n", usys_get_cpu_id());[m
[32m+[m
[32m+[m	[32mret = usys_set_affinity(-1, aff);[m
[32m+[m	[32mfail_cond(ret != 0, "Set affinity failed\n");[m
[32m+[m
[32m+[m	[32mprintf("Main thread set affinity %d\n", aff);[m
[32m+[m
[32m+[m	[32musys_yield();[m
[32m+[m
[32m+[m	[32mret = usys_get_affinity(-1);[m
[32m+[m
[32m+[m	[32mprintf("Main thread affinity %d\n", ret);[m
[32m+[m
[32m+[m	[32mprintf("Main thread exits on cpu_id: %u\n", usys_get_cpu_id());[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/yield_multi.c b/user/lab4/yield_multi.c[m
[1mnew file mode 100644[m
[1mindex 0000000..b4bf61b[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/yield_multi.c[m
[36m@@ -0,0 +1,47 @@[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/thread.h>[m
[32m+[m
[32m+[m[32m#define PRIO 255[m
[32m+[m[32m#define INFO 233[m
[32m+[m
[32m+[m[32m#define THREAD_NUM 4[m
[32m+[m
[32m+[m[32mvolatile u64 start_flags[THREAD_NUM];[m
[32m+[m
[32m+[m[32mvoid *thread_routine(void *arg)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 thread_id = (u64) arg;[m
[32m+[m
[32m+[m	[32mwhile (start_flags[thread_id] == 0) ;[m
[32m+[m
[32m+[m	[32mprintf("Hello, I am thread %u on cpu %u\n", thread_id,[m
[32m+[m	[32m       usys_get_cpu_id());[m
[32m+[m
[32m+[m	[32mstart_flags[(thread_id + 1) % THREAD_NUM] = 1;[m
[32m+[m
[32m+[m	[32m/* usys_exit: just de-schedule itself without reclaiming the resource */[m
[32m+[m	[32musys_exit(0);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[])[m
[32m+[m[32m{[m
[32m+[m	[32mint child_thread_cap;[m
[32m+[m	[32mint i;[m
[32m+[m	[32mu64 thread_i;[m
[32m+[m
[32m+[m	[32mfor (thread_i = 0; thread_i < THREAD_NUM; ++thread_i) {[m
[32m+[m		[32mstart_flags[thread_i] = 0;[m
[32m+[m		[32mchild_thread_cap =[m
[32m+[m		[32m    create_thread(thread_routine, thread_i, PRIO, thread_i % 4);[m
[32m+[m		[32mif (child_thread_cap < 0)[m
[32m+[m			[32mprintf("Create thread failed, return %d\n",[m
[32m+[m			[32m       child_thread_cap);[m
[32m+[m		[32mfor (i = 0; i < 10000; i++) ;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mstart_flags[0] = 1;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/yield_multi_aff.c b/user/lab4/yield_multi_aff.c[m
[1mnew file mode 100644[m
[1mindex 0000000..b8c8514[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/yield_multi_aff.c[m
[36m@@ -0,0 +1,64 @@[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/thread.h>[m
[32m+[m
[32m+[m[32m#define PRIO 255[m
[32m+[m[32m#define INFO 233[m
[32m+[m
[32m+[m[32m#define THREAD_NUM 4[m
[32m+[m
[32m+[m[32mvolatile u64 start_flags[THREAD_NUM];[m
[32m+[m[32mint child_thread_caps[THREAD_NUM];[m
[32m+[m
[32m+[m[32mvoid *thread_routine(void *arg)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 times = 0;[m
[32m+[m	[32mu64 thread_id = (u64) arg;[m
[32m+[m	[32mu64 next_thread_id = (thread_id + 1) % THREAD_NUM;[m
[32m+[m	[32mu64 prev_thread_id = (thread_id + THREAD_NUM - 1) % THREAD_NUM;[m
[32m+[m	[32mint aff;[m
[32m+[m
[32m+[m	[32mwhile (times < 3) {[m
[32m+[m		[32mtimes++;[m
[32m+[m		[32mwhile (start_flags[thread_id] == 0) ;[m
[32m+[m		[32mstart_flags[thread_id] = 0;[m
[32m+[m
[32m+[m		[32musys_yield();[m
[32m+[m
[32m+[m		[32maff = usys_get_affinity(child_thread_caps[thread_id]);[m
[32m+[m
[32m+[m		[32mprintf("Iteration %lu, thread %lu, cpu %u, aff %d\n", times,[m
[32m+[m		[32m       thread_id, usys_get_cpu_id(), aff);[m
[32m+[m
[32m+[m		[32musys_set_affinity(child_thread_caps[prev_thread_id],[m
[32m+[m				[32m  (thread_id + times) % 4);[m
[32m+[m
[32m+[m		[32mstart_flags[next_thread_id] = 1;[m
[32m+[m
[32m+[m		[32musys_yield();[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/* usys_exit: just de-schedule itself without reclaiming the resource */[m
[32m+[m	[32musys_exit(0);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[])[m
[32m+[m[32m{[m
[32m+[m	[32mint i;[m
[32m+[m	[32mu64 thread_i;[m
[32m+[m
[32m+[m	[32mfor (thread_i = 0; thread_i < THREAD_NUM; ++thread_i) {[m
[32m+[m		[32mstart_flags[thread_i] = 0;[m
[32m+[m		[32mchild_thread_caps[thread_i] =[m
[32m+[m		[32m    create_thread(thread_routine, thread_i, PRIO, thread_i % 4);[m
[32m+[m		[32mif (child_thread_caps[thread_i] < 0)[m
[32m+[m			[32mprintf("Create thread failed, return %d\n",[m
[32m+[m			[32m       child_thread_caps[thread_i]);[m
[32m+[m		[32mfor (i = 0; i < 10000; i++) ;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mstart_flags[0] = 1;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/yield_single.c b/user/lab4/yield_single.c[m
[1mnew file mode 100644[m
[1mindex 0000000..7681fe5[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/yield_single.c[m
[36m@@ -0,0 +1,42 @@[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/thread.h>[m
[32m+[m
[32m+[m[32m#define PRIO 255[m
[32m+[m[32m#define INFO 233[m
[32m+[m
[32m+[m[32mvoid *thread_routine(void *arg)[m
[32m+[m[32m{[m
[32m+[m	[32mu32 times = 0;[m
[32m+[m	[32mu64 thread_id = (u64) arg;[m
[32m+[m
[32m+[m	[32mprintf("Hello, I am thread %u\n", thread_id);[m
[32m+[m	[32musys_yield();[m
[32m+[m
[32m+[m	[32mwhile (times++ < 10) {[m
[32m+[m		[32mprintf("Iteration %lu, thread %lu, cpu %u\n", times, thread_id,[m
[32m+[m		[32m       usys_get_cpu_id());[m
[32m+[m		[32musys_yield();[m
[32m+[m	[32m}[m
[32m+[m	[32m/* usys_exit: just de-schedule itself without reclaiming the resource */[m
[32m+[m	[32musys_exit(0);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[])[m
[32m+[m[32m{[m
[32m+[m	[32mint child_thread_cap;[m
[32m+[m	[32mint i;[m
[32m+[m	[32mu64 thread_i;[m
[32m+[m
[32m+[m	[32mfor (thread_i = 0; thread_i < 2; ++thread_i) {[m
[32m+[m		[32mchild_thread_cap =[m
[32m+[m		[32m    create_thread(thread_routine, thread_i, PRIO, 0);[m
[32m+[m		[32mif (child_thread_cap < 0)[m
[32m+[m			[32mprintf("Create thread failed, return %d\n",[m
[32m+[m			[32m       child_thread_cap);[m
[32m+[m		[32mfor (i = 0; i < 10000; i++) ;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lab4/yield_spin.c b/user/lab4/yield_spin.c[m
[1mnew file mode 100644[m
[1mindex 0000000..dc64462[m
[1m--- /dev/null[m
[1m+++ b/user/lab4/yield_spin.c[m
[36m@@ -0,0 +1,37 @@[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/thread.h>[m
[32m+[m
[32m+[m[32m#define PRIO 255[m
[32m+[m[32m#define INFO 233[m
[32m+[m
[32m+[m[32mbool running = true;[m
[32m+[m
[32m+[m[32mvoid *thread_routine(void *arg)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 thread_id = (u64) arg;[m
[32m+[m
[32m+[m	[32mprintf("Hello, I am thread %u\n", thread_id);[m
[32m+[m
[32m+[m	[32mwhile (running) {[m
[32m+[m
[32m+[m	[32m}[m
[32m+[m	[32m/* usys_exit: just de-schedule itself without reclaiming the resource */[m
[32m+[m	[32musys_exit(0);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint main(int argc, char *argv[])[m
[32m+[m[32m{[m
[32m+[m	[32mint child_thread_cap;[m
[32m+[m
[32m+[m	[32mchild_thread_cap = create_thread(thread_routine, 0, PRIO, 0);[m
[32m+[m	[32mif (child_thread_cap < 0)[m
[32m+[m		[32mprintf("Create thread failed, return %d\n", child_thread_cap);[m
[32m+[m
[32m+[m	[32musys_yield();[m
[32m+[m
[32m+[m	[32mprintf("Successfully regain the control!\n");[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/cpio.c b/user/lib/cpio.c[m
[1mnew file mode 100644[m
[1mindex 0000000..87b6de4[m
[1m--- /dev/null[m
[1m+++ b/user/lib/cpio.c[m
[36m@@ -0,0 +1,153 @@[m
[32m+[m[32m#include <lib/cpio.h>[m
[32m+[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/errno.h>[m
[32m+[m[32m#include <lib/string.h>[m
[32m+[m[32m#include <lib/malloc.h>[m
[32m+[m
[32m+[m[32m#define kwarn printf[m
[32m+[m[32m#define cpio_info(fmt, ...) printf(fmt, ## __VA_ARGS__)[m
[32m+[m[32m#define cpio_zalloc(sz) calloc(1, sz)[m
[32m+[m[32m#define cpio_free(obj) free(obj)[m
[32m+[m
[32m+[m[32mstatic u64 hex8_u64(const char s[8])[m
[32m+[m[32m{[m
[32m+[m	[32mu64 u = 0;[m
[32m+[m	[32mfor (int i = 0; i < 8; ++i) {[m
[32m+[m		[32mu <<= 4;[m
[32m+[m		[32mif (s[i] >= 'A' && s[i] <= 'F')[m
[32m+[m			[32mu += s[i] - 'A' + 10;[m
[32m+[m		[32melse[m
[32m+[m			[32mu += s[i] - '0';[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn u;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic int cpio_parse_header(const void *addr, struct cpio_header *header)[m
[32m+[m[32m{[m
[32m+[m	[32mconst struct cpio_newc_header *newc = addr;[m
[32m+[m
[32m+[m	[32m// cpio_info("print in text: %s\n", addr);[m
[32m+[m	[32m/* headers other than newc are not supported */[m
[32m+[m	[32mBUG_ON(strncmp(newc->c_magic, "070701", 6));[m
[32m+[m
[32m+[m	[32mheader->c_ino = hex8_u64(newc->c_ino);[m
[32m+[m	[32mheader->c_mode = hex8_u64(newc->c_mode);[m
[32m+[m	[32mheader->c_uid = hex8_u64(newc->c_uid);[m
[32m+[m	[32mheader->c_gid = hex8_u64(newc->c_gid);[m
[32m+[m	[32mheader->c_nlink = hex8_u64(newc->c_nlink);[m
[32m+[m	[32mheader->c_mtime = hex8_u64(newc->c_mtime);[m
[32m+[m	[32mheader->c_filesize = hex8_u64(newc->c_filesize);[m
[32m+[m	[32mheader->c_devmajor = hex8_u64(newc->c_devmajor);[m
[32m+[m	[32mheader->c_devminor = hex8_u64(newc->c_devminor);[m
[32m+[m	[32mheader->c_rdevmajor = hex8_u64(newc->c_rdevmajor);[m
[32m+[m	[32mheader->c_rdevminor = hex8_u64(newc->c_rdevminor);[m
[32m+[m	[32mheader->c_namesize = hex8_u64(newc->c_namesize);[m
[32m+[m	[32mheader->c_check = hex8_u64(newc->c_check);[m
[32m+[m
[32m+[m	[32m// cpio_info("header address is 0x%lx\n", (u64) header);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint cpio_extract_file(const void *addr, const char *dirat)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid cpio_init_g_files(void)[m
[32m+[m[32m{[m
[32m+[m	[32mg_files.head.next = NULL;[m
[32m+[m	[32mg_files.tail = &g_files.head;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic struct cpio_file *cpio_alloc_file(void)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn cpio_zalloc(sizeof(struct cpio_file));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic void cpio_add_file(struct cpio_file *f)[m
[32m+[m[32m{[m
[32m+[m	[32mf->next = NULL;[m
[32m+[m	[32mg_files.tail->next = f;[m
[32m+[m	[32mg_files.tail = f;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#define ALIGN4_UP(x) ((((u64)x) & (~3llu)) + ((!!(((u64)x) & 3)) << 2))[m
[32m+[m
[32m+[m[32mvoid cpio_extract(const void *addr, const char *dirat)[m
[32m+[m[32m{[m
[32m+[m	[32mconst char *p = addr;[m
[32m+[m	[32mstruct cpio_file *f;[m
[32m+[m	[32mint err;[m
[32m+[m
[32m+[m	[32mfor (;;) {[m
[32m+[m		[32mf = cpio_alloc_file();[m
[32m+[m		[32m// printf("cpio_alloc_file returns %p\n", f);[m
[32m+[m		[32mif (f == NULL) {[m
[32m+[m			[32mkwarn("cpio_alloc_file fails due to lack of memory.\n");[m
[32m+[m			[32mreturn;[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mBUG_ON(!f);[m
[32m+[m
[32m+[m		[32merr = cpio_parse_header(p, &f->header);[m
[32m+[m		[32mBUG_ON(err);[m
[32m+[m		[32mp += sizeof(struct cpio_newc_header);[m
[32m+[m
[32m+[m		[32mif (0 == strcmp(p, "TRAILER!!!")) {[m
[32m+[m			[32m// cpio_free(f);[m
[32m+[m			[32mbreak;[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mf->name = p;[m
[32m+[m		[32mp += f->header.c_namesize;[m
[32m+[m		[32mp = (void *)ALIGN4_UP(p);[m
[32m+[m
[32m+[m		[32mf->data = p;[m
[32m+[m		[32mp += f->header.c_filesize;[m
[32m+[m		[32mp = (void *)ALIGN4_UP(p);[m
[32m+[m
[32m+[m		[32mcpio_add_file(f);[m
[32m+[m	[32m}[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid *cpio_extract_single(const void *addr, const char *target,[m
[32m+[m			[32m  void *(*cpio_single_file_filler) (const void *start,[m
[32m+[m							[32m    size_t size,[m
[32m+[m							[32m    void *data),[m
[32m+[m			[32m  void *data)[m
[32m+[m[32m{[m
[32m+[m	[32mconst char *p = addr;[m
[32m+[m	[32mstruct cpio_header header;[m
[32m+[m	[32mconst char *filename;[m
[32m+[m
[32m+[m	[32m/* Skip leading '/' */[m
[32m+[m	[32mtarget = target + 1;[m
[32m+[m
[32m+[m	[32mfor (;;) {[m
[32m+[m		[32mint err;[m
[32m+[m
[32m+[m		[32merr = cpio_parse_header(p, &header);[m
[32m+[m		[32mBUG_ON(err);[m
[32m+[m		[32mp += sizeof(struct cpio_newc_header);[m
[32m+[m
[32m+[m		[32mif (0 == strcmp(p, "TRAILER!!!"))[m
[32m+[m			[32mbreak;[m
[32m+[m
[32m+[m		[32mfilename = p;[m
[32m+[m		[32mp += header.c_namesize;[m
[32m+[m		[32mp = (void *)ALIGN4_UP(p);[m
[32m+[m
[32m+[m		[32mif (0 == strcmp(filename, target)) {[m
[32m+[m			[32mreturn cpio_single_file_filler(p, header.c_filesize,[m
[32m+[m						[32m       data);[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mp += header.c_filesize;[m
[32m+[m		[32mp = (void *)ALIGN4_UP(p);[m
[32m+[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn ERR_PTR(-ENOENT);[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/cpio.h b/user/lib/cpio.h[m
[1mnew file mode 100644[m
[1mindex 0000000..2bccd40[m
[1m--- /dev/null[m
[1m+++ b/user/lib/cpio.h[m
[36m@@ -0,0 +1,73 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32m/* Spec from https://man.openbsd.org/FreeBSD-12.0/cpio.5 */[m
[32m+[m
[32m+[m[32mstruct cpio_newc_header {[m
[32m+[m	[32mchar c_magic[6];[m
[32m+[m	[32mchar c_ino[8];[m
[32m+[m	[32mchar c_mode[8];[m
[32m+[m	[32mchar c_uid[8];[m
[32m+[m	[32mchar c_gid[8];[m
[32m+[m	[32mchar c_nlink[8];[m
[32m+[m	[32mchar c_mtime[8];[m
[32m+[m	[32mchar c_filesize[8];[m
[32m+[m	[32mchar c_devmajor[8];[m
[32m+[m	[32mchar c_devminor[8];[m
[32m+[m	[32mchar c_rdevmajor[8];[m
[32m+[m	[32mchar c_rdevminor[8];[m
[32m+[m	[32mchar c_namesize[8];[m
[32m+[m	[32mchar c_check[8];[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct cpio_header {[m
[32m+[m	[32mchar c_magic[6];[m
[32m+[m	[32mu64 c_ino;[m
[32m+[m	[32mu64 c_mode;[m
[32m+[m	[32mu64 c_uid;[m
[32m+[m	[32mu64 c_gid;[m
[32m+[m	[32mu64 c_nlink;[m
[32m+[m	[32mu64 c_mtime;[m
[32m+[m	[32mu64 c_filesize;[m
[32m+[m	[32mu64 c_devmajor;[m
[32m+[m	[32mu64 c_devminor;[m
[32m+[m	[32mu64 c_rdevmajor;[m
[32m+[m	[32mu64 c_rdevminor;[m
[32m+[m	[32mu64 c_namesize;[m
[32m+[m	[32mu64 c_check;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m#define cpio_fatal(fmt, ...) do { \[m
[32m+[m	[32mfprintf(stderr, "CPIO tool fatal error: " fmt, ##__VA_ARGS__); \[m
[32m+[m	[32mexit(-1); \[m
[32m+[m[32m} while (0)[m
[32m+[m
[32m+[m[32m#define cpio_fatal_e(fmt, ...) do { \[m
[32m+[m	[32mfprintf(stderr, "CPIO tool fatal error (%s): " fmt, \[m
[32m+[m		[32mstrerror(errno), ##__VA_ARGS__); \[m
[32m+[m	[32mexit(-1); \[m
[32m+[m[32m} while (0)[m
[32m+[m
[32m+[m[32m#define ALIGN4_UP(x) ((((u64)x) & (~3llu)) + ((!!(((u64)x) & 3)) << 2))[m
[32m+[m
[32m+[m[32mstruct cpio_file {[m
[32m+[m	[32mstruct cpio_header header;[m
[32m+[m	[32mconst char *name;[m
[32m+[m	[32mconst char *data;[m
[32m+[m	[32mstruct cpio_file *next;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct {[m
[32m+[m	[32mstruct cpio_file head;[m
[32m+[m	[32mstruct cpio_file *tail;[m
[32m+[m[32m} g_files;[m
[32m+[m
[32m+[m[32mvoid cpio_init_g_files(void);[m
[32m+[m[32mint cpio_extract_file(const void *addr, const char *dirat);[m
[32m+[m[32mvoid cpio_extract(const void *addr, const char *dirat);[m
[32m+[m[32mvoid *cpio_extract_single(const void *addr, const char *target,[m
[32m+[m			[32m  void *(*cpio_single_file_filler) (const void *start,[m
[32m+[m							[32m    size_t size,[m
[32m+[m							[32m    void *data),[m
[32m+[m			[32m  void *data);[m
[1mdiff --git a/user/lib/elf.c b/user/lib/elf.c[m
[1mnew file mode 100644[m
[1mindex 0000000..cc9b515[m
[1m--- /dev/null[m
[1m+++ b/user/lib/elf.c[m
[36m@@ -0,0 +1,305 @@[m
[32m+[m[32m#include <lib/elf.h>[m
[32m+[m[32m#include <lib/errno.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/endianness.h>[m
[32m+[m
[32m+[m[32m#define PAGE_SIZE 0x1000[m
[32m+[m
[32m+[m[32mstatic bool is_elf_magic(struct elf_indent *indent)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn (indent->ei_magic[0] == 0x7F &&[m
[32m+[m		[32mindent->ei_magic[1] == 'E' &&[m
[32m+[m		[32mindent->ei_magic[2] == 'L' && indent->ei_magic[3] == 'F');[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#define ELF_ENDIAN_LE(indent) ((indent).ei_data == 1)[m
[32m+[m[32m#define ELF_ENDIAN_BE(indent) ((indent).ei_data == 2)[m
[32m+[m
[32m+[m[32m#define ELF_BITS_32(indent) ((indent).ei_class == 1)[m
[32m+[m[32m#define ELF_BITS_64(indent) ((indent).ei_class == 2)[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Parse an ELF file header. We use the 64-bit structure `struct elf_header` as[m
[32m+[m[32m * the output structure.[m
[32m+[m[32m *[m
[32m+[m[32m * On error, the negative error code is returned.[m
[32m+[m[32m * On success, 0 is returned, and the header is written in the given parameter.[m
[32m+[m[32m */[m
[32m+[m[32mstatic int parse_elf_header(const char *code, struct elf_header *header)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct elf_header *header_64 = (struct elf_header *)code;[m
[32m+[m	[32mstruct elf_header_32 *header_32 = (struct elf_header_32 *)code;[m
[32m+[m
[32m+[m	[32mif (!is_elf_magic(&header_64->e_indent)) {[m
[32m+[m		[32mreturn -EINVAL;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mheader->e_indent = *(struct elf_indent *)code;[m
[32m+[m
[32m+[m	[32mif (ELF_ENDIAN_LE(header->e_indent)) {[m
[32m+[m		[32m/*[m
[32m+[m		[32m * For the first few bytes, both 32-bit and 64-bit ELF headers[m
[32m+[m		[32m * have the same field width. So, we simply use header_64 at[m
[32m+[m		[32m * first.[m
[32m+[m		[32m */[m
[32m+[m		[32mheader->e_type = le16_to_cpu(header_64->e_type);[m
[32m+[m		[32mheader->e_machine = le16_to_cpu(header_64->e_machine);[m
[32m+[m		[32mheader->e_version = le32_to_cpu(header_32->e_version);[m
[32m+[m		[32mif (ELF_BITS_32(header->e_indent)) {[m
[32m+[m			[32mheader->e_entry = le32_to_cpu(header_32->e_entry);[m
[32m+[m			[32mheader->e_phoff = le32_to_cpu(header_32->e_phoff);[m
[32m+[m			[32mheader->e_shoff = le32_to_cpu(header_32->e_shoff);[m
[32m+[m			[32mheader->e_flags = le32_to_cpu(header_32->e_flags);[m
[32m+[m			[32mheader->e_ehsize = le16_to_cpu(header_32->e_ehsize);[m
[32m+[m			[32mheader->e_phentsize =[m
[32m+[m			[32m    le16_to_cpu(header_32->e_phentsize);[m
[32m+[m			[32mheader->e_phnum = le16_to_cpu(header_32->e_phnum);[m
[32m+[m			[32mheader->e_shentsize =[m
[32m+[m			[32m    le16_to_cpu(header_32->e_shentsize);[m
[32m+[m			[32mheader->e_shnum = le16_to_cpu(header_32->e_shnum);[m
[32m+[m			[32mheader->e_shstrndx = le16_to_cpu(header_32->e_shstrndx);[m
[32m+[m		[32m} else if (ELF_BITS_64(header->e_indent)) {[m
[32m+[m			[32mheader->e_entry = le64_to_cpu(header_64->e_entry);[m
[32m+[m			[32mheader->e_phoff = le64_to_cpu(header_64->e_phoff);[m
[32m+[m			[32mheader->e_shoff = le64_to_cpu(header_64->e_shoff);[m
[32m+[m			[32mheader->e_flags = le32_to_cpu(header_64->e_flags);[m
[32m+[m			[32mheader->e_ehsize = le16_to_cpu(header_64->e_ehsize);[m
[32m+[m			[32mheader->e_phentsize =[m
[32m+[m			[32m    le16_to_cpu(header_64->e_phentsize);[m
[32m+[m			[32mheader->e_phnum = le16_to_cpu(header_64->e_phnum);[m
[32m+[m			[32mheader->e_shentsize =[m
[32m+[m			[32m    le16_to_cpu(header_64->e_shentsize);[m
[32m+[m			[32mheader->e_shnum = le16_to_cpu(header_64->e_shnum);[m
[32m+[m			[32mheader->e_shstrndx = le16_to_cpu(header_64->e_shstrndx);[m
[32m+[m		[32m} else {[m
[32m+[m			[32mreturn -EINVAL;[m
[32m+[m		[32m}[m
[32m+[m	[32m} else if (ELF_ENDIAN_BE(header->e_indent)) {[m
[32m+[m		[32m/*[m
[32m+[m		[32m * We use header_64 for the same reason as above.[m
[32m+[m		[32m */[m
[32m+[m		[32mheader->e_type = be16_to_cpu(header_64->e_type);[m
[32m+[m		[32mheader->e_machine = be16_to_cpu(header_64->e_machine);[m
[32m+[m		[32mheader->e_version = be32_to_cpu(header_32->e_version);[m
[32m+[m		[32mif (ELF_BITS_32(header->e_indent)) {[m
[32m+[m			[32mheader->e_entry = be32_to_cpu(header_32->e_entry);[m
[32m+[m			[32mheader->e_phoff = be32_to_cpu(header_32->e_phoff);[m
[32m+[m			[32mheader->e_shoff = be32_to_cpu(header_32->e_shoff);[m
[32m+[m			[32mheader->e_flags = be32_to_cpu(header_32->e_flags);[m
[32m+[m			[32mheader->e_ehsize = be16_to_cpu(header_32->e_ehsize);[m
[32m+[m			[32mheader->e_phentsize =[m
[32m+[m			[32m    be16_to_cpu(header_32->e_phentsize);[m
[32m+[m			[32mheader->e_phnum = be16_to_cpu(header_32->e_phnum);[m
[32m+[m			[32mheader->e_shentsize =[m
[32m+[m			[32m    be16_to_cpu(header_32->e_shentsize);[m
[32m+[m			[32mheader->e_shnum = be16_to_cpu(header_32->e_shnum);[m
[32m+[m			[32mheader->e_shstrndx = be16_to_cpu(header_32->e_shstrndx);[m
[32m+[m		[32m} else if (ELF_BITS_64(header->e_indent)) {[m
[32m+[m			[32mheader->e_entry = be64_to_cpu(header_64->e_entry);[m
[32m+[m			[32mheader->e_phoff = be64_to_cpu(header_64->e_phoff);[m
[32m+[m			[32mheader->e_shoff = be64_to_cpu(header_64->e_shoff);[m
[32m+[m			[32mheader->e_flags = be32_to_cpu(header_64->e_flags);[m
[32m+[m			[32mheader->e_ehsize = be16_to_cpu(header_64->e_ehsize);[m
[32m+[m			[32mheader->e_phentsize =[m
[32m+[m			[32m    be16_to_cpu(header_64->e_phentsize);[m
[32m+[m			[32mheader->e_phnum = be16_to_cpu(header_64->e_phnum);[m
[32m+[m			[32mheader->e_shentsize =[m
[32m+[m			[32m    be16_to_cpu(header_64->e_shentsize);[m
[32m+[m			[32mheader->e_shnum = be16_to_cpu(header_64->e_shnum);[m
[32m+[m			[32mheader->e_shstrndx = be16_to_cpu(header_64->e_shstrndx);[m
[32m+[m		[32m} else {[m
[32m+[m			[32mreturn -EINVAL;[m
[32m+[m		[32m}[m
[32m+[m	[32m} else {[m
[32m+[m		[32mreturn -EINVAL;[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Parse an ELF program header. We use the 64-bit structure[m
[32m+[m[32m * `struct elf_program_header` as the output structure.[m
[32m+[m[32m *[m
[32m+[m[32m * On error, the negative error code is returned.[m
[32m+[m[32m * On success, 0 is returned, and the header is written in the given parameter.[m
[32m+[m[32m */[m
[32m+[m[32mstatic int parse_elf_program_header(const char *code,[m
[32m+[m				[32m    const struct elf_header *elf,[m
[32m+[m				[32m    struct elf_program_header *header)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct elf_program_header *header_64;[m
[32m+[m	[32mstruct elf_program_header_32 *header_32;[m
[32m+[m
[32m+[m	[32mif (ELF_ENDIAN_LE(elf->e_indent)) {[m
[32m+[m		[32mif (ELF_BITS_32(elf->e_indent)) {[m
[32m+[m			[32mheader_32 = (struct elf_program_header_32 *)code;[m
[32m+[m			[32mheader->p_type = le32_to_cpu(header_32->p_type);[m
[32m+[m			[32mheader->p_flags = le32_to_cpu(header_32->p_flags);[m
[32m+[m			[32mheader->p_offset = le32_to_cpu(header_32->p_offset);[m
[32m+[m			[32mheader->p_vaddr = le32_to_cpu(header_32->p_vaddr);[m
[32m+[m			[32mheader->p_paddr = le32_to_cpu(header_32->p_paddr);[m
[32m+[m			[32mheader->p_filesz = le32_to_cpu(header_32->p_filesz);[m
[32m+[m			[32mheader->p_memsz = le32_to_cpu(header_32->p_memsz);[m
[32m+[m			[32mheader->p_align = le32_to_cpu(header_32->p_align);[m
[32m+[m		[32m} else if (ELF_BITS_64(elf->e_indent)) {[m
[32m+[m			[32mheader_64 = (struct elf_program_header *)code;[m
[32m+[m			[32mheader->p_type = le32_to_cpu(header_64->p_type);[m
[32m+[m			[32mheader->p_flags = le32_to_cpu(header_64->p_flags);[m
[32m+[m			[32mheader->p_offset = le64_to_cpu(header_64->p_offset);[m
[32m+[m			[32mheader->p_vaddr = le64_to_cpu(header_64->p_vaddr);[m
[32m+[m			[32mheader->p_paddr = le64_to_cpu(header_64->p_paddr);[m
[32m+[m			[32mheader->p_filesz = le64_to_cpu(header_64->p_filesz);[m
[32m+[m			[32mheader->p_memsz = le64_to_cpu(header_64->p_memsz);[m
[32m+[m			[32mheader->p_align = le64_to_cpu(header_64->p_align);[m
[32m+[m		[32m} else {[m
[32m+[m			[32mreturn -EINVAL;[m
[32m+[m		[32m}[m
[32m+[m	[32m} else if (ELF_ENDIAN_BE(elf->e_indent)) {[m
[32m+[m		[32mif (ELF_BITS_32(elf->e_indent)) {[m
[32m+[m			[32mheader_32 = (struct elf_program_header_32 *)code;[m
[32m+[m			[32mheader->p_type = be32_to_cpu(header_32->p_type);[m
[32m+[m			[32mheader->p_flags = be32_to_cpu(header_32->p_flags);[m
[32m+[m			[32mheader->p_offset = be32_to_cpu(header_32->p_offset);[m
[32m+[m			[32mheader->p_vaddr = be32_to_cpu(header_32->p_vaddr);[m
[32m+[m			[32mheader->p_paddr = be32_to_cpu(header_32->p_paddr);[m
[32m+[m			[32mheader->p_filesz = be32_to_cpu(header_32->p_filesz);[m
[32m+[m			[32mheader->p_memsz = be32_to_cpu(header_32->p_memsz);[m
[32m+[m			[32mheader->p_align = be32_to_cpu(header_32->p_align);[m
[32m+[m		[32m} else if (ELF_BITS_64(elf->e_indent)) {[m
[32m+[m			[32mheader_64 = (struct elf_program_header *)code;[m
[32m+[m			[32mheader->p_type = be32_to_cpu(header_64->p_type);[m
[32m+[m			[32mheader->p_flags = be32_to_cpu(header_64->p_flags);[m
[32m+[m			[32mheader->p_offset = be64_to_cpu(header_64->p_offset);[m
[32m+[m			[32mheader->p_vaddr = be64_to_cpu(header_64->p_vaddr);[m
[32m+[m			[32mheader->p_paddr = be64_to_cpu(header_64->p_paddr);[m
[32m+[m			[32mheader->p_filesz = be64_to_cpu(header_64->p_filesz);[m
[32m+[m			[32mheader->p_memsz = be64_to_cpu(header_64->p_memsz);[m
[32m+[m			[32mheader->p_align = be64_to_cpu(header_64->p_align);[m
[32m+[m		[32m} else {[m
[32m+[m			[32mreturn -EINVAL;[m
[32m+[m		[32m}[m
[32m+[m	[32m} else {[m
[32m+[m		[32mreturn -EINVAL;[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/**[m
[32m+[m[32m * Parse an ELF section header. We use the 64-bit structure[m
[32m+[m[32m * `struct elf_section_header` as the output structure.[m
[32m+[m[32m *[m
[32m+[m[32m * On error, the negative error code is returned.[m
[32m+[m[32m * On success, 0 is returned, and the header is written in the given parameter.[m
[32m+[m[32m */[m
[32m+[m[32mstatic int parse_elf_section_header(const char *code,[m
[32m+[m				[32m    const struct elf_header *elf,[m
[32m+[m				[32m    struct elf_section_header *header)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct elf_section_header *header_64;[m
[32m+[m	[32mstruct elf_section_header_32 *header_32;[m
[32m+[m
[32m+[m	[32mif (ELF_ENDIAN_LE(elf->e_indent)) {[m
[32m+[m		[32mif (ELF_BITS_32(elf->e_indent)) {[m
[32m+[m			[32mheader_32 = (struct elf_section_header_32 *)code;[m
[32m+[m			[32mheader->sh_name = le32_to_cpu(header_32->sh_name);[m
[32m+[m			[32mheader->sh_type = le32_to_cpu(header_32->sh_type);[m
[32m+[m			[32mheader->sh_flags = le32_to_cpu(header_32->sh_flags);[m
[32m+[m			[32mheader->sh_addr = le32_to_cpu(header_32->sh_addr);[m
[32m+[m			[32mheader->sh_offset = le32_to_cpu(header_32->sh_offset);[m
[32m+[m			[32mheader->sh_size = le32_to_cpu(header_32->sh_size);[m
[32m+[m			[32mheader->sh_link = le32_to_cpu(header_32->sh_link);[m
[32m+[m			[32mheader->sh_info = le32_to_cpu(header_32->sh_info);[m
[32m+[m			[32mheader->sh_addralign =[m
[32m+[m			[32m    le32_to_cpu(header_32->sh_addralign);[m
[32m+[m			[32mheader->sh_entsize = le32_to_cpu(header_32->sh_entsize);[m
[32m+[m		[32m} else if (ELF_BITS_64(elf->e_indent)) {[m
[32m+[m			[32mheader_64 = (struct elf_section_header *)code;[m
[32m+[m			[32mheader->sh_name = le32_to_cpu(header_64->sh_name);[m
[32m+[m			[32mheader->sh_type = le32_to_cpu(header_64->sh_type);[m
[32m+[m			[32mheader->sh_flags = le64_to_cpu(header_64->sh_flags);[m
[32m+[m			[32mheader->sh_addr = le64_to_cpu(header_64->sh_addr);[m
[32m+[m			[32mheader->sh_offset = le64_to_cpu(header_64->sh_offset);[m
[32m+[m			[32mheader->sh_size = le64_to_cpu(header_64->sh_size);[m
[32m+[m			[32mheader->sh_link = le32_to_cpu(header_64->sh_link);[m
[32m+[m			[32mheader->sh_info = le32_to_cpu(header_64->sh_info);[m
[32m+[m			[32mheader->sh_addralign =[m
[32m+[m			[32m    le64_to_cpu(header_64->sh_addralign);[m
[32m+[m			[32mheader->sh_entsize = le64_to_cpu(header_64->sh_entsize);[m
[32m+[m		[32m} else {[m
[32m+[m			[32mreturn -EINVAL;[m
[32m+[m		[32m}[m
[32m+[m	[32m} else if (ELF_ENDIAN_BE(elf->e_indent)) {[m
[32m+[m		[32mif (ELF_BITS_32(elf->e_indent)) {[m
[32m+[m			[32mheader_32 = (struct elf_section_header_32 *)code;[m
[32m+[m			[32mheader->sh_name = be32_to_cpu(header_32->sh_name);[m
[32m+[m			[32mheader->sh_type = be32_to_cpu(header_32->sh_type);[m
[32m+[m			[32mheader->sh_flags = be32_to_cpu(header_32->sh_flags);[m
[32m+[m			[32mheader->sh_addr = be32_to_cpu(header_32->sh_addr);[m
[32m+[m			[32mheader->sh_offset = be32_to_cpu(header_32->sh_offset);[m
[32m+[m			[32mheader->sh_size = be32_to_cpu(header_32->sh_size);[m
[32m+[m			[32mheader->sh_link = be32_to_cpu(header_32->sh_link);[m
[32m+[m			[32mheader->sh_info = be32_to_cpu(header_32->sh_info);[m
[32m+[m			[32mheader->sh_addralign =[m
[32m+[m			[32m    be32_to_cpu(header_32->sh_addralign);[m
[32m+[m			[32mheader->sh_entsize = be32_to_cpu(header_32->sh_entsize);[m
[32m+[m		[32m} else if (ELF_BITS_64(elf->e_indent)) {[m
[32m+[m			[32mheader_64 = (struct elf_section_header *)code;[m
[32m+[m			[32mheader->sh_name = be32_to_cpu(header_64->sh_name);[m
[32m+[m			[32mheader->sh_type = be32_to_cpu(header_64->sh_type);[m
[32m+[m			[32mheader->sh_flags = be64_to_cpu(header_64->sh_flags);[m
[32m+[m			[32mheader->sh_addr = be64_to_cpu(header_64->sh_addr);[m
[32m+[m			[32mheader->sh_offset = be64_to_cpu(header_64->sh_offset);[m
[32m+[m			[32mheader->sh_size = be64_to_cpu(header_64->sh_size);[m
[32m+[m			[32mheader->sh_link = be32_to_cpu(header_64->sh_link);[m
[32m+[m			[32mheader->sh_info = be32_to_cpu(header_64->sh_info);[m
[32m+[m			[32mheader->sh_addralign =[m
[32m+[m			[32m    be64_to_cpu(header_64->sh_addralign);[m
[32m+[m			[32mheader->sh_entsize = be64_to_cpu(header_64->sh_entsize);[m
[32m+[m		[32m} else {[m
[32m+[m			[32mreturn -EINVAL;[m
[32m+[m		[32m}[m
[32m+[m	[32m} else {[m
[32m+[m		[32mreturn -EINVAL;[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstruct elf_file *elf_parse_file(const char *code, struct elf_file *elf)[m
[32m+[m[32m{[m
[32m+[m	[32mint err;[m
[32m+[m	[32mint i;[m
[32m+[m
[32m+[m	[32mif (!elf)[m
[32m+[m		[32mreturn ERR_PTR(-ENOMEM);[m
[32m+[m
[32m+[m	[32merr = parse_elf_header(code, &elf->header);[m
[32m+[m	[32mif (err)[m
[32m+[m		[32mgoto out;[m
[32m+[m
[32m+[m	[32m/* Allocate memory for program headers and section headers */[m
[32m+[m	[32merr = -ENOMEM;[m
[32m+[m
[32m+[m	[32m/* Parse program headers and section headers */[m
[32m+[m	[32mfor (i = 0; i < elf->header.e_phnum; ++i) {[m
[32m+[m		[32merr = parse_elf_program_header(code + elf->header.e_phoff +[m
[32m+[m					[32m       elf->header.e_phentsize * i,[m
[32m+[m					[32m       &elf->header,[m
[32m+[m					[32m       &elf->p_headers[i]);[m
[32m+[m		[32mif (err)[m
[32m+[m			[32mgoto out;[m
[32m+[m	[32m}[m
[32m+[m	[32mfor (i = 0; i < elf->header.e_shnum; ++i) {[m
[32m+[m		[32merr = parse_elf_section_header(code + elf->header.e_shoff +[m
[32m+[m					[32m       elf->header.e_shentsize * i,[m
[32m+[m					[32m       &elf->header,[m
[32m+[m					[32m       &elf->s_headers[i]);[m
[32m+[m		[32mif (err)[m
[32m+[m			[32mgoto out;[m
[32m+[m	[32m}[m
[32m+[m	[32mreturn elf;[m
[32m+[m
[32m+[m[32m out:[m
[32m+[m	[32mreturn ERR_PTR((long)err);[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/elf.h b/user/lib/elf.h[m
[1mnew file mode 100644[m
[1mindex 0000000..10aae6f[m
[1m--- /dev/null[m
[1m+++ b/user/lib/elf.h[m
[36m@@ -0,0 +1,137 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m[32m#include <lib/errno.h>[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * ELF format according to[m
[32m+[m[32m * https://en.wikipedia.org/wiki/Executable_and_Linkable_Format[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#define EI_MAG_SIZE 4[m
[32m+[m
[32m+[m[32m#define PT_NULL		0x00000000[m
[32m+[m[32m#define PT_LOAD		0x00000001[m
[32m+[m[32m#define PT_DYNAMIC	0x00000002[m
[32m+[m[32m#define PT_INTERP	0x00000003[m
[32m+[m[32m#define PT_NOTE		0x00000004[m
[32m+[m[32m#define PT_SHLIB	0x00000005[m
[32m+[m[32m#define PT_PHDR		0x00000006[m
[32m+[m[32m#define PT_LOOS		0x60000000[m
[32m+[m[32m#define PT_HIOS		0x6fffffff[m
[32m+[m[32m#define PT_LOPROC	0x70000000[m
[32m+[m[32m#define PT_HIRPOC	0x7fffffff[m
[32m+[m
[32m+[m[32m#define PF_ALL	0x7[m
[32m+[m[32m#define PF_X	0x1[m
[32m+[m[32m#define PF_W	0x2[m
[32m+[m[32m#define PF_R	0x4[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * This part of ELF header is endianness-independent.[m
[32m+[m[32m */[m
[32m+[m[32mstruct elf_indent {[m
[32m+[m	[32mu8 ei_magic[4];[m
[32m+[m	[32mu8 ei_class;[m
[32m+[m	[32mu8 ei_data;[m
[32m+[m	[32mu8 ei_version;[m
[32m+[m	[32mu8 ei_osabi;[m
[32m+[m	[32mu8 ei_abiversion;[m
[32m+[m	[32mu8 ei_pad[7];[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * ELF header format. One should check the `e_indent` to decide the endianness.[m
[32m+[m[32m */[m
[32m+[m[32mstruct elf_header {[m
[32m+[m	[32mstruct elf_indent e_indent;[m
[32m+[m	[32mu16 e_type;[m
[32m+[m	[32mu16 e_machine;[m
[32m+[m	[32mu32 e_version;[m
[32m+[m	[32mu64 e_entry;[m
[32m+[m	[32mu64 e_phoff;[m
[32m+[m	[32mu64 e_shoff;[m
[32m+[m	[32mu32 e_flags;[m
[32m+[m	[32mu16 e_ehsize;[m
[32m+[m	[32mu16 e_phentsize;[m
[32m+[m	[32mu16 e_phnum;[m
[32m+[m	[32mu16 e_shentsize;[m
[32m+[m	[32mu16 e_shnum;[m
[32m+[m	[32mu16 e_shstrndx;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m/*[m
[32m+[m[32m * 32-Bit of the elf_header. Check the `e_indent` first to decide.[m
[32m+[m[32m */[m
[32m+[m[32mstruct elf_header_32 {[m
[32m+[m	[32mstruct elf_indent e_indent;[m
[32m+[m	[32mu16 e_type;[m
[32m+[m	[32mu16 e_machine;[m
[32m+[m	[32mu32 e_version;[m
[32m+[m	[32mu32 e_entry;[m
[32m+[m	[32mu32 e_phoff;[m
[32m+[m	[32mu32 e_shoff;[m
[32m+[m	[32mu32 e_flags;[m
[32m+[m	[32mu16 e_ehsize;[m
[32m+[m	[32mu16 e_phentsize;[m
[32m+[m	[32mu16 e_phnum;[m
[32m+[m	[32mu16 e_shentsize;[m
[32m+[m	[32mu16 e_shnum;[m
[32m+[m	[32mu16 e_shstrndx;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct elf_program_header {[m
[32m+[m	[32mu32 p_type;[m
[32m+[m	[32mu32 p_flags;[m
[32m+[m	[32mu64 p_offset;[m
[32m+[m	[32mu64 p_vaddr;[m
[32m+[m	[32mu64 p_paddr;[m
[32m+[m	[32mu64 p_filesz;[m
[32m+[m	[32mu64 p_memsz;[m
[32m+[m	[32mu64 p_align;[m
[32m+[m[32m};[m
[32m+[m[32mstruct elf_program_header_32 {[m
[32m+[m	[32mu32 p_type;[m
[32m+[m	[32mu32 p_offset;[m
[32m+[m	[32mu32 p_vaddr;[m
[32m+[m	[32mu32 p_paddr;[m
[32m+[m	[32mu32 p_filesz;[m
[32m+[m	[32mu32 p_memsz;[m
[32m+[m	[32mu32 p_flags;[m
[32m+[m	[32mu32 p_align;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct elf_section_header {[m
[32m+[m	[32mu32 sh_name;[m
[32m+[m	[32mu32 sh_type;[m
[32m+[m	[32mu64 sh_flags;[m
[32m+[m	[32mu64 sh_addr;[m
[32m+[m	[32mu64 sh_offset;[m
[32m+[m	[32mu64 sh_size;[m
[32m+[m	[32mu32 sh_link;[m
[32m+[m	[32mu32 sh_info;[m
[32m+[m	[32mu64 sh_addralign;[m
[32m+[m	[32mu64 sh_entsize;[m
[32m+[m[32m};[m
[32m+[m[32mstruct elf_section_header_32 {[m
[32m+[m	[32mu32 sh_name;[m
[32m+[m	[32mu32 sh_type;[m
[32m+[m	[32mu32 sh_flags;[m
[32m+[m	[32mu32 sh_addr;[m
[32m+[m	[32mu32 sh_offset;[m
[32m+[m	[32mu32 sh_size;[m
[32m+[m	[32mu32 sh_link;[m
[32m+[m	[32mu32 sh_info;[m
[32m+[m	[32mu32 sh_addralign;[m
[32m+[m	[32mu32 sh_entsize;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m#define MAX_P_HEADERS 128[m
[32m+[m[32m#define MAX_S_HEADERS 128[m
[32m+[m[32mstruct elf_file {[m
[32m+[m	[32mstruct elf_header header;[m
[32m+[m	[32mstruct elf_program_header p_headers[MAX_P_HEADERS];[m
[32m+[m	[32mstruct elf_section_header s_headers[MAX_S_HEADERS];[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct elf_file *elf_parse_file(const char *code, struct elf_file *elf);[m
[1mdiff --git a/user/lib/endianness.h b/user/lib/endianness.h[m
[1mnew file mode 100644[m
[1mindex 0000000..196acc5[m
[1m--- /dev/null[m
[1m+++ b/user/lib/endianness.h[m
[36m@@ -0,0 +1,54 @@[m
[32m+[m[32m/*[m
[32m+[m[32m * Copyright (c) 2020 Institute of Parallel And Distributed Systems (IPADS), Shanghai Jiao Tong University (SJTU)[m
[32m+[m[32m * OS-Lab-2020 (i.e., ChCore) is licensed under the Mulan PSL v1.[m
[32m+[m[32m * You can use this software according to the terms and conditions of the Mulan PSL v1.[m
[32m+[m[32m * You may obtain a copy of Mulan PSL v1 at:[m
[32m+[m[32m *   http://license.coscl.org.cn/MulanPSL[m
[32m+[m[32m *   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR[m
[32m+[m[32m *   IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR[m
[32m+[m[32m *   PURPOSE.[m
[32m+[m[32m *   See the Mulan PSL v1 for more details.[m
[32m+[m[32m */[m
[32m+[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32m#define le16_to_cpu(x) (x)[m
[32m+[m[32m#define le32_to_cpu(x) (x)[m
[32m+[m[32m#define le64_to_cpu(x) (x)[m
[32m+[m
[32m+[m[32m#define be16_to_cpu(x) ((((x) & 0xff) << 8) | (((x) >> 8) & 0xff))[m
[32m+[m[32m#define be32_to_cpu(x) ((be16_to_cpu((x)) << 16) | (be16_to_cpu((x) >> 16)))[m
[32m+[m[32m#define be64_to_cpu(x) ((be32_to_cpu((x)) << 32) | (be32_to_cpu((x) >> 32)))[m
[32m+[m
[32m+[m[32m#define be128ptr_to_cpu_hi(x) (be64_to_cpu(*(u64 *)(x)))[m
[32m+[m[32m#define be128ptr_to_cpu_lo(x) (be64_to_cpu(*((u64 *)(x) + 1)))[m
[32m+[m
[32m+[m[32m#define be96ptr_to_cpu_hi(x) (be32_to_cpu(*(u32 *)(x)))[m
[32m+[m[32m#define be96ptr_to_cpu_lo(x) (((u64)(be32_to_cpu(*((u32 *)(x) + 1)))) << 32 | \[m
[32m+[m			[32m      (be32_to_cpu(*((u32 *)(x)) + 2)))[m
[32m+[m
[32m+[m[32m#define beXptr_to_cpu(bits, n) \[m
[32m+[m	[32m({ \[m
[32m+[m	[32m (bits == 32) ? be32_to_cpu(*(u32 *)(n)) : \[m
[32m+[m	[32m (bits == 64) ? be64_to_cpu(*(u64 *)(n)) : \[m
[32m+[m	[32m ({ BUG("invalid X"); 0; }); \[m
[32m+[m	[32m })[m
[32m+[m
[32m+[m[32m#define set_beXptr_to_cpu(bits, n, hi, lo) do {     \[m
[32m+[m	[32mif (bits > 64) {                            \[m
[32m+[m		[32mif (bits == 96) {                   \[m
[32m+[m			[32mlo = be96ptr_to_cpu_lo(n);  \[m
[32m+[m			[32mhi = be96ptr_to_cpu_hi(n);  \[m
[32m+[m		[32m} else if (bits == 128) {           \[m
[32m+[m			[32mlo = be128ptr_to_cpu_lo(n); \[m
[32m+[m			[32mhi = be128ptr_to_cpu_hi(n); \[m
[32m+[m		[32m} else {                            \[m
[32m+[m			[32mBUG("invalid X");           \[m
[32m+[m		[32m}                                   \[m
[32m+[m	[32m} else {                                    \[m
[32m+[m		[32mlo = 0;                             \[m
[32m+[m		[32mhi = beXptr_to_cpu(bits, n);        \[m
[32m+[m	[32m}                                           \[m
[32m+[m[32m} while (0)[m
[1mdiff --git a/user/lib/fs_defs.h b/user/lib/fs_defs.h[m
[1mnew file mode 100644[m
[1mindex 0000000..be1a7f2[m
[1m--- /dev/null[m
[1m+++ b/user/lib/fs_defs.h[m
[36m@@ -0,0 +1,56 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#define TMPFS_MAP_BUF	1[m
[32m+[m[32m#define TMPFS_SCAN	2[m
[32m+[m[32m#define TMPFS_MKDIR	3[m
[32m+[m[32m#define TMPFS_RMDIR	4[m
[32m+[m[32m#define TMPFS_CREAT	5[m
[32m+[m[32m#define TMPFS_UNLINK	6[m
[32m+[m[32m#define TMPFS_OPEN	7[m
[32m+[m[32m#define TMPFS_CLOSE	8[m
[32m+[m[32m#define TMPFS_WRITE	9[m
[32m+[m[32m#define TMPFS_READ	10[m
[32m+[m
[32m+[m[32m#define TMPFS_GET_SIZE	999[m
[32m+[m
[32m+[m[32m#define TMPFS_INFO_VADDR 0x200000[m
[32m+[m[32m#define TMPFS_SCAN_BUF_VADDR 0x20000000[m
[32m+[m[32m#define TMPFS_READ_BUF_VADDR 0x30000000[m
[32m+[m
[32m+[m[32menum FS_REQ {[m
[32m+[m	[32mFS_REQ_OPEN = 0,[m
[32m+[m	[32mFS_REQ_CLOSE,[m
[32m+[m
[32m+[m	[32mFS_REQ_CREAT,[m
[32m+[m	[32mFS_REQ_MKDIR,[m
[32m+[m	[32mFS_REQ_RMDIR,[m
[32m+[m	[32mFS_REQ_UNLINK,[m
[32m+[m
[32m+[m	[32mFS_REQ_SCAN,[m
[32m+[m	[32mFS_REQ_READ,[m
[32m+[m	[32mFS_REQ_WRITE,[m
[32m+[m
[32m+[m	[32mFS_REQ_GET_SIZE[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m#define FS_REQ_PATH_LEN (256)[m
[32m+[m[32mstruct fs_request {[m
[32m+[m	[32menum FS_REQ req;[m
[32m+[m
[32m+[m	[32mchar *buff;[m
[32m+[m	[32mint flags;[m
[32m+[m	[32moff_t offset;[m
[32m+[m	[32mssize_t count;[m
[32m+[m
[32m+[m	[32mchar path[FS_REQ_PATH_LEN];[m
[32m+[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct dirent {[m
[32m+[m	[32mino_t d_ino;		/* Inode number */[m
[32m+[m	[32moff_t d_off;		/* Not an offset; see below */[m
[32m+[m	[32munsigned short d_reclen;	/* Length of this record */[m
[32m+[m	[32munsigned char d_type;	/* Type of file; not supported[m
[32m+[m				[32m   by all filesystem types */[m
[32m+[m	[32mchar d_name[256];	/* Null-terminated filename */[m
[32m+[m[32m};[m
[1mdiff --git a/user/lib/ipc.c b/user/lib/ipc.c[m
[1mnew file mode 100644[m
[1mindex 0000000..aab6dba[m
[1m--- /dev/null[m
[1m+++ b/user/lib/ipc.c[m
[36m@@ -0,0 +1,125 @@[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/string.h>[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m
[32m+[m[32mipc_msg_t *ipc_create_msg(ipc_struct_t * icb, u64 data_len, u64 cap_slot_number)[m
[32m+[m[32m{[m
[32m+[m	[32mipc_msg_t *ipc_msg;[m
[32m+[m	[32mint i;[m
[32m+[m
[32m+[m	[32mipc_msg = (ipc_msg_t *) icb->shared_buf;[m
[32m+[m	[32mipc_msg->data_len = data_len;[m
[32m+[m	[32mipc_msg->cap_slot_number = cap_slot_number;[m
[32m+[m
[32m+[m	[32mipc_msg->data_offset = sizeof(*ipc_msg);[m
[32m+[m	[32mipc_msg->cap_slots_offset = ipc_msg->data_offset + data_len;[m
[32m+[m	[32mmemset(ipc_get_msg_data(ipc_msg), 0, data_len);[m
[32m+[m	[32mfor (i = 0; i < cap_slot_number; i++)[m
[32m+[m		[32mipc_set_msg_cap(ipc_msg, i, -1);[m
[32m+[m
[32m+[m	[32mreturn ipc_msg;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mchar *ipc_get_msg_data(ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn (char *)ipc_msg + ipc_msg->data_offset;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint ipc_set_msg_data(ipc_msg_t * ipc_msg, char *data, u64 offset, u64 len)[m
[32m+[m[32m{[m
[32m+[m	[32mif (offset + len < offset || offset + len > ipc_msg->data_len)[m
[32m+[m		[32mreturn -1;[m
[32m+[m
[32m+[m	[32mmemcpy(ipc_get_msg_data(ipc_msg) + offset, data, len);[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mstatic u64 *ipc_get_msg_cap_ptr(ipc_msg_t * ipc_msg, u64 cap_id)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn (u64 *) ((char *)ipc_msg + ipc_msg->cap_slots_offset) + cap_id;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mu64 ipc_get_msg_cap(ipc_msg_t * ipc_msg, u64 cap_slot_index)[m
[32m+[m[32m{[m
[32m+[m	[32mif (cap_slot_index >= ipc_msg->cap_slot_number)[m
[32m+[m		[32mreturn -1;[m
[32m+[m	[32mreturn *ipc_get_msg_cap_ptr(ipc_msg, cap_slot_index);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint ipc_set_msg_cap(ipc_msg_t * ipc_msg, u64 cap_slot_index, u32 cap)[m
[32m+[m[32m{[m
[32m+[m	[32mif (cap_slot_index >= ipc_msg->cap_slot_number)[m
[32m+[m		[32mreturn -1;[m
[32m+[m	[32m*ipc_get_msg_cap_ptr(ipc_msg, cap_slot_index) = cap;[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m/* FIXME: currently ipc_msg is not dynamically allocated so that no need to free */[m
[32m+[m[32mint ipc_destroy_msg(ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#define SERVER_STACK_BASE	0x7000000[m
[32m+[m[32m#define SERVER_STACK_SIZE	0x1000[m
[32m+[m[32m#define SERVER_BUF_BASE		0x7400000[m
[32m+[m[32m#define SERVER_BUF_SIZE		0x1000[m
[32m+[m[32m#define CLIENT_BUF_BASE		0x7800000[m
[32m+[m[32m#define CLIENT_BUF_SIZE		0x1000[m
[32m+[m[32m#define MAX_CLIENT		16[m
[32m+[m
[32m+[m[32mint ipc_register_server(server_handler server_handler)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct ipc_vm_config vm_config = {[m
[32m+[m		[32m.stack_base_addr = SERVER_STACK_BASE,[m
[32m+[m		[32m.stack_size = SERVER_STACK_SIZE,[m
[32m+[m		[32m.buf_base_addr = SERVER_BUF_BASE,[m
[32m+[m		[32m.buf_size = SERVER_BUF_SIZE,[m
[32m+[m	[32m};[m
[32m+[m	[32mreturn usys_register_server((u64) server_handler, MAX_CLIENT,[m
[32m+[m				[32m    (u64) & vm_config);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint ipc_register_client(int server_thread_cap, ipc_struct_t * ipc_struct)[m
[32m+[m[32m{[m
[32m+[m	[32mint conn_cap;[m
[32m+[m
[32m+[m	[32mstruct ipc_vm_config vm_config = {[m
[32m+[m		[32m.buf_base_addr = CLIENT_BUF_BASE,[m
[32m+[m		[32m.buf_size = CLIENT_BUF_SIZE,[m
[32m+[m	[32m};[m
[32m+[m
[32m+[m	[32mconn_cap = usys_register_client((u32) server_thread_cap,[m
[32m+[m					[32m(u64) & vm_config);[m
[32m+[m
[32m+[m	[32mif (conn_cap < 0)[m
[32m+[m		[32mreturn -1;[m
[32m+[m	[32mipc_struct->shared_buf = vm_config.buf_base_addr;[m
[32m+[m	[32mipc_struct->shared_buf_len = vm_config.buf_size;[m
[32m+[m	[32mipc_struct->conn_cap = conn_cap;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint ipc_call(ipc_struct_t * icb, ipc_msg_t * ipc_msg)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 ret = 0;[m
[32m+[m	[32mret = usys_ipc_call(icb->conn_cap, (u64) ipc_msg);[m
[32m+[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint ipc_reg_call(ipc_struct_t * icb, u64 arg)[m
[32m+[m[32m{[m
[32m+[m	[32mu64 ret = 0;[m
[32m+[m	[32mret = usys_ipc_reg_call(icb->conn_cap, (u64) arg);[m
[32m+[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid ipc_return(int ret)[m
[32m+[m[32m{[m
[32m+[m	[32musys_ipc_return((u64) ret);[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/ipc.h b/user/lib/ipc.h[m
[1mnew file mode 100644[m
[1mindex 0000000..11f4eff[m
[1m--- /dev/null[m
[1m+++ b/user/lib/ipc.h[m
[36m@@ -0,0 +1,41 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m[32mtypedef struct ipc_struct {[m
[32m+[m	[32mu64 conn_cap;[m
[32m+[m	[32mu64 shared_buf;[m
[32m+[m	[32mu64 shared_buf_len;[m
[32m+[m[32m} ipc_struct_t;[m
[32m+[m
[32m+[m[32mtypedef struct ipc_msg {[m
[32m+[m	[32mu64 server_conn_cap;[m
[32m+[m	[32mu64 data_len;[m
[32m+[m	[32mu64 cap_slot_number;[m
[32m+[m	[32mu64 data_offset;[m
[32m+[m	[32mu64 cap_slots_offset;[m
[32m+[m[32m} ipc_msg_t;[m
[32m+[m
[32m+[m[32mstruct ipc_vm_config {[m
[32m+[m	[32mu64 stack_base_addr;[m
[32m+[m	[32mu64 stack_size;[m
[32m+[m	[32mu64 buf_base_addr;[m
[32m+[m	[32mu64 buf_size;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mint ipc_register_client(int server_thread_cap, ipc_struct_t * ipc_struct);[m
[32m+[m[32mipc_msg_t *ipc_create_msg(ipc_struct_t * icb, u64 data_len,[m
[32m+[m			[32m  u64 cap_slot_number);[m
[32m+[m[32mchar *ipc_get_msg_data(ipc_msg_t * ipc_msg);[m
[32m+[m[32mu64 ipc_get_msg_cap(ipc_msg_t * ipc_msg, u64 cap_id);[m
[32m+[m[32mint ipc_set_msg_data(ipc_msg_t * ipc_msg, char *data, u64 offset, u64 len);[m
[32m+[m[32mint ipc_set_msg_cap(ipc_msg_t * ipc_msg, u64 cap_slot_index, u32 cap);[m
[32m+[m[32mint ipc_destroy_msg(ipc_msg_t * ipc_msg);[m
[32m+[m
[32m+[m[32mint ipc_call(ipc_struct_t * icb, ipc_msg_t * ipc_msg);[m
[32m+[m[32mint ipc_reg_call(ipc_struct_t * icb, u64 arg);[m
[32m+[m[32mvoid ipc_return(int ret);[m
[32m+[m
[32m+[m[32mtypedef void (*server_handler) (ipc_msg_t * ipc_msg);[m
[32m+[m[32mint ipc_register_server(server_handler server_handler);[m
[32m+[m
[32m+[m[32m#define INFO_PAGE_VADDR ((void *)0x100000ll)[m
[1mdiff --git a/user/lib/launcher.h b/user/lib/launcher.h[m
[1mnew file mode 100644[m
[1mindex 0000000..94379bf[m
[1m--- /dev/null[m
[1m+++ b/user/lib/launcher.h[m
[36m@@ -0,0 +1,21 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/cpio.h>[m
[32m+[m
[32m+[m[32m#include <lib/elf.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/proc.h>[m
[32m+[m
[32m+[m[32mstruct info_page {[m
[32m+[m	[32mvolatile u64 ready_flag;[m
[32m+[m	[32mvolatile u64 exit_flag;[m
[32m+[m	[32mu64 nr_args;[m
[32m+[m	[32mu64 args[];[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m#define CPIO_BIN 0x5000000[m
[32m+[m
[32m+[m[32mint parse_elf_from_binary(const char *binary, struct user_elf *user_elf);[m
[32m+[m[32mvoid *single_file_handler(const void *start, size_t size, void *data);[m
[32m+[m[32mint readelf_from_kernel_cpio(const char *filename, struct user_elf *user_elf);[m
[32m+[m[32mint readelf_from_fs(const char *pathbuf, struct user_elf *user_elf);[m
[1mdiff --git a/user/lib/liblauncher.c b/user/lib/liblauncher.c[m
[1mnew file mode 100644[m
[1mindex 0000000..3058069[m
[1m--- /dev/null[m
[1m+++ b/user/lib/liblauncher.c[m
[36m@@ -0,0 +1,165 @@[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/errno.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/ipc.h>[m
[32m+[m[32m#include <lib/bug.h>[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/string.h>[m
[32m+[m[32m#include <lib/fs_defs.h>[m
[32m+[m
[32m+[m[32m#define VMR_READ  (1 << 0)[m
[32m+[m[32m#define VMR_WRITE (1 << 1)[m
[32m+[m[32m#define VMR_EXEC  (1 << 2)[m
[32m+[m
[32m+[m[32m#define PFLAGS2VMRFLAGS(PF) \[m
[32m+[m	[32m(((PF)&PF_X ? VMR_EXEC : 0) | ((PF)&PF_W ? VMR_WRITE : 0) | \[m
[32m+[m	[32m ((PF)&PF_R ? VMR_READ : 0))[m
[32m+[m
[32m+[m[32m#define OFFSET_MASK 0xfff[m
[32m+[m
[32m+[m[32mint parse_elf_from_binary(const char *binary, struct user_elf *user_elf)[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mstruct elf_file elf;[m
[32m+[m	[32msize_t seg_sz, seg_map_sz;[m
[32m+[m	[32mu64 p_vaddr;[m
[32m+[m	[32mint i;[m
[32m+[m	[32mint j;[m
[32m+[m	[32mu64 tmp_vaddr = 0xc00000;[m
[32m+[m
[32m+[m	[32melf_parse_file(binary, &elf);[m
[32m+[m
[32m+[m	[32m/* init pmo, -1 indicates that this pmo is not used[m
[32m+[m	[32m *[m
[32m+[m	[32m * Currently, an elf file can have 2 PT_LOAD segment at most[m
[32m+[m	[32m */[m
[32m+[m	[32mfor (i = 0; i < 2; ++i)[m
[32m+[m		[32muser_elf->user_elf_seg[i].elf_pmo = -1;[m
[32m+[m
[32m+[m	[32mfor (i = 0, j = 0; i < elf.header.e_phnum; ++i) {[m
[32m+[m		[32mif (elf.p_headers[i].p_type != PT_LOAD)[m
[32m+[m			[32mcontinue;[m
[32m+[m
[32m+[m		[32mseg_sz = elf.p_headers[i].p_memsz;[m
[32m+[m		[32mp_vaddr = elf.p_headers[i].p_vaddr;[m
[32m+[m		[32mBUG_ON(elf.p_headers[i].p_filesz > seg_sz);[m
[32m+[m		[32mseg_map_sz = ROUND_UP(seg_sz + p_vaddr, PAGE_SIZE) -[m
[32m+[m		[32m    ROUND_DOWN(p_vaddr, PAGE_SIZE);[m
[32m+[m
[32m+[m		[32muser_elf->user_elf_seg[j].elf_pmo =[m
[32m+[m		[32m    usys_create_pmo(seg_map_sz, PMO_DATA);[m
[32m+[m		[32mBUG_ON(user_elf->user_elf_seg[j].elf_pmo < 0);[m
[32m+[m
[32m+[m		[32mret = usys_map_pmo(SELF_CAP,[m
[32m+[m				[32m   user_elf->user_elf_seg[j].elf_pmo,[m
[32m+[m				[32m   tmp_vaddr, VM_READ | VM_WRITE);[m
[32m+[m		[32mBUG_ON(ret < 0);[m
[32m+[m
[32m+[m		[32mmemset((void *)tmp_vaddr, 0, seg_map_sz);[m
[32m+[m		[32m/*[m
[32m+[m		[32m * OFFSET_MASK is for calculating the final offset for loading[m
[32m+[m		[32m * different segments from ELF.[m
[32m+[m		[32m * ELF segment can specify not aligned address.[m
[32m+[m		[32m *[m
[32m+[m		[32m */[m
[32m+[m		[32mmemcpy((void *)tmp_vaddr +[m
[32m+[m		[32m       (elf.p_headers[i].p_vaddr & OFFSET_MASK),[m
[32m+[m		[32m       (void *)(binary +[m
[32m+[m				[32melf.p_headers[i].p_offset),[m
[32m+[m		[32m       elf.p_headers[i].p_filesz);[m
[32m+[m
[32m+[m		[32muser_elf->user_elf_seg[j].seg_sz = seg_sz;[m
[32m+[m		[32muser_elf->user_elf_seg[j].p_vaddr = p_vaddr;[m
[32m+[m		[32muser_elf->user_elf_seg[j].flags =[m
[32m+[m		[32m    PFLAGS2VMRFLAGS(elf.p_headers[i].p_flags);[m
[32m+[m		[32musys_unmap_pmo(SELF_CAP,[m
[32m+[m			[32m       user_elf->user_elf_seg[j].elf_pmo, tmp_vaddr);[m
[32m+[m
[32m+[m		[32mj++;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32muser_elf->elf_meta.phdr_addr = elf.p_headers[0].p_vaddr +[m
[32m+[m	[32m    elf.header.e_phoff;[m
[32m+[m	[32muser_elf->elf_meta.phentsize = elf.header.e_phentsize;[m
[32m+[m	[32muser_elf->elf_meta.phnum = elf.header.e_phnum;[m
[32m+[m	[32muser_elf->elf_meta.flags = elf.header.e_flags;[m
[32m+[m	[32muser_elf->elf_meta.entry = elf.header.e_entry;[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid *single_file_handler(const void *start, size_t size, void *data)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct user_elf *user_elf = data;[m
[32m+[m	[32mvoid *ret;[m
[32m+[m
[32m+[m	[32mret = (void *)(s64) parse_elf_from_binary(start, user_elf);[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint readelf_from_kernel_cpio(const char *filename, struct user_elf *user_elf)[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m
[32m+[m	[32mstrcpy(user_elf->path, filename);[m
[32m+[m	[32mret = (int)(s64) cpio_extract_single((void *)CPIO_BIN, filename,[m
[32m+[m					[32m     single_file_handler, user_elf);[m
[32m+[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mipc_struct_t *tmpfs_ipc_struct;[m
[32m+[m[32mstatic int fs_read(const char *path, int *tmpfs_read_pmo_cap)[m
[32m+[m[32m{[m
[32m+[m	[32mipc_msg_t *ipc_msg;[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mstruct fs_request fr;[m
[32m+[m
[32m+[m	[32m/* IPC send cap */[m
[32m+[m	[32mipc_msg = ipc_create_msg(tmpfs_ipc_struct,[m
[32m+[m				[32m sizeof(struct fs_request), 1);[m
[32m+[m	[32mfr.req = FS_REQ_GET_SIZE;[m
[32m+[m	[32mstrcpy((void *)fr.path, path);[m
[32m+[m	[32mipc_set_msg_data(ipc_msg, (char *)&fr, 0, sizeof(struct fs_request));[m
[32m+[m	[32mret = ipc_call(tmpfs_ipc_struct, ipc_msg);[m
[32m+[m
[32m+[m	[32m*tmpfs_read_pmo_cap = usys_create_pmo(ret, PMO_DATA);[m
[32m+[m
[32m+[m	[32mfr.req = FS_REQ_READ;[m
[32m+[m	[32mstrcpy((void *)fr.path, path);[m
[32m+[m	[32mfr.offset = 0;[m
[32m+[m	[32mfr.buff = (char *)TMPFS_READ_BUF_VADDR;[m
[32m+[m	[32mfr.count = ret;[m
[32m+[m	[32mfr.req = FS_REQ_READ;[m
[32m+[m	[32mipc_set_msg_cap(ipc_msg, 0, *tmpfs_read_pmo_cap);[m
[32m+[m	[32mipc_set_msg_data(ipc_msg, (char *)&fr, 0, sizeof(struct fs_request));[m
[32m+[m	[32mret = ipc_call(tmpfs_ipc_struct, ipc_msg);[m
[32m+[m
[32m+[m	[32mipc_destroy_msg(ipc_msg);[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint readelf_from_fs(const char *pathbuf, struct user_elf *user_elf)[m
[32m+[m[32m{[m
[32m+[m	[32mint ret;[m
[32m+[m	[32mint tmpfs_read_pmo_cap;[m
[32m+[m
[32m+[m	[32mret = fs_read(pathbuf, &tmpfs_read_pmo_cap);[m
[32m+[m	[32mif (ret < 0) {[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP,[m
[32m+[m			[32m   tmpfs_read_pmo_cap,[m
[32m+[m			[32m   TMPFS_READ_BUF_VADDR, VM_READ | VM_WRITE);[m
[32m+[m	[32mBUG_ON(ret < 0);[m
[32m+[m
[32m+[m	[32mstrcpy(user_elf->path, pathbuf);[m
[32m+[m	[32mret = parse_elf_from_binary((const char *)TMPFS_READ_BUF_VADDR,[m
[32m+[m				[32m    user_elf);[m
[32m+[m
[32m+[m	[32musys_unmap_pmo(SELF_CAP, tmpfs_read_pmo_cap, TMPFS_READ_BUF_VADDR);[m
[32m+[m
[32m+[m	[32mreturn ret;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/libmain.c b/user/lib/libmain.c[m
[1mindex 7cfcab6..c3e6abb 100644[m
[1m--- a/user/lib/libmain.c[m
[1m+++ b/user/lib/libmain.c[m
[36m@@ -13,5 +13,6 @@[m [mvoid _start_c(long *p)[m
 	 * Lab3: Your code here[m
 	 * Complete the main function[m
 	 */[m
[32m+[m	[32musys_exit(0);[m
 	return;[m
 }[m
[1mdiff --git a/user/lib/malloc.c b/user/lib/malloc.c[m
[1mnew file mode 100644[m
[1mindex 0000000..180cd2a[m
[1m--- /dev/null[m
[1m+++ b/user/lib/malloc.c[m
[36m@@ -0,0 +1,65 @@[m
[32m+[m[32m#include "malloc.h"[m
[32m+[m[32m#include "bug.h"[m
[32m+[m[32m#include "string.h"[m
[32m+[m[32m#include "syscall.h"[m
[32m+[m
[32m+[m[32m#define PMO_SIZE        0x1000[m
[32m+[m[32m#define MAP_VA          0x1000000[m
[32m+[m
[32m+[m[32m/* virtual memory rights */[m
[32m+[m[32m#define VM_READ  (1 << 0)[m
[32m+[m[32m#define VM_WRITE (1 << 1)[m
[32m+[m[32m#define VM_EXEC  (1 << 2)[m
[32m+[m
[32m+[m[32m/* PMO types */[m
[32m+[m[32m#define PMO_ANONYM 0[m
[32m+[m[32m#define PMO_DATA   1[m
[32m+[m
[32m+[m[32m/* a thread's own cap_group */[m
[32m+[m[32m#define SELF_CAP   0[m
[32m+[m
[32m+[m[32m#define MALLOC_SZ (50ull * 1024 * 1024)[m
[32m+[m[32mstatic char *malloc_buf_;[m
[32m+[m[32mstatic size_t malloc_header_ = 0;[m
[32m+[m
[32m+[m[32mvoid *malloc(size_t size)[m
[32m+[m[32m{[m
[32m+[m	[32mBUG_ON(malloc_header_ + size > MALLOC_SZ);[m
[32m+[m
[32m+[m	[32mif (malloc_header_ == 0) {[m
[32m+[m		[32mint pmo_cap, r;[m
[32m+[m		[32mpmo_cap = usys_create_pmo(MALLOC_SZ, PMO_ANONYM);[m
[32m+[m		[32mif (pmo_cap < 0) {[m
[32m+[m			[32mprintf("usys_create_pmo ret:%d\n", pmo_cap);[m
[32m+[m			[32musys_exit(pmo_cap);[m
[32m+[m		[32m}[m
[32m+[m		[32mr = usys_map_pmo(SELF_CAP, pmo_cap, MAP_VA, VM_READ | VM_WRITE);[m
[32m+[m		[32mif (r < 0) {[m
[32m+[m			[32mprintf("usys_map_pmo ret:%d\n", r);[m
[32m+[m			[32musys_exit(r);[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32mmalloc_buf_ = (char *)MAP_VA;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mvoid *ptr = (void *)&malloc_buf_[malloc_header_];[m
[32m+[m	[32mmalloc_header_ += size;[m
[32m+[m
[32m+[m	[32mreturn ptr;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid *calloc(size_t nmemb, size_t size)[m
[32m+[m[32m{[m
[32m+[m	[32m(void)nmemb;[m
[32m+[m	[32m(void)size;[m
[32m+[m
[32m+[m	[32mvoid *ptr = malloc(nmemb * size);[m
[32m+[m	[32mmemset(ptr, 0, nmemb * size);[m
[32m+[m
[32m+[m	[32mreturn ptr;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mvoid free(void *ptr)[m
[32m+[m[32m{[m
[32m+[m	[32m(void)ptr;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/malloc.h b/user/lib/malloc.h[m
[1mnew file mode 100644[m
[1mindex 0000000..a8e5e71[m
[1m--- /dev/null[m
[1m+++ b/user/lib/malloc.h[m
[36m@@ -0,0 +1,6 @@[m
[32m+[m[32m#pragma once[m
[32m+[m[32m#include "type.h"[m
[32m+[m
[32m+[m[32mvoid *malloc(size_t size);[m
[32m+[m[32mvoid *calloc(size_t nmemb, size_t size);[m
[32m+[m[32mvoid free(void *ptr);[m
[1mdiff --git a/user/lib/proc.h b/user/lib/proc.h[m
[1mnew file mode 100644[m
[1mindex 0000000..66a73b6[m
[1m--- /dev/null[m
[1m+++ b/user/lib/proc.h[m
[36m@@ -0,0 +1,35 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32mstruct pmo_request {[m
[32m+[m	[32m/* input: args */[m
[32m+[m	[32mu64 size;[m
[32m+[m	[32mu64 type;[m
[32m+[m
[32m+[m	[32m/* output: return value */[m
[32m+[m	[32mu64 ret_cap;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mstruct pmo_map_request {[m
[32m+[m	[32m/* input: args */[m
[32m+[m	[32mu64 pmo_cap;[m
[32m+[m	[32mu64 addr;[m
[32m+[m	[32mu64 perm;[m
[32m+[m
[32m+[m	[32m/* output: return value */[m
[32m+[m	[32mu64 ret;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32mint launch_process(struct user_elf *user_elf,[m
[32m+[m		[32m   int *child_process_cap,[m
[32m+[m		[32m   int *child_main_thread_cap,[m
[32m+[m		[32m   struct pmo_map_request *pmo_map_reqs,[m
[32m+[m		[32m   int nr_pmo_map_reqs, int caps[], int nr_caps, int cpuid);[m
[32m+[m
[32m+[m[32mint launch_process_with_pmos_caps(struct user_elf *user_elf,[m
[32m+[m				[32m  int *child_process_cap,[m
[32m+[m				[32m  int *child_main_thread_cap,[m
[32m+[m				[32m  struct pmo_map_request *pmo_map_reqs,[m
[32m+[m				[32m  int nr_pmo_map_reqs, int caps[], int nr_caps,[m
[32m+[m				[32m  s32 aff);[m
[1mdiff --git a/user/lib/spawn.c b/user/lib/spawn.c[m
[1mnew file mode 100644[m
[1mindex 0000000..501b779[m
[1m--- /dev/null[m
[1m+++ b/user/lib/spawn.c[m
[36m@@ -0,0 +1,424 @@[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/errno.h>[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/proc.h>[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m
[32m+[m[32m/* main thread info */[m
[32m+[m[32mstruct mt_info {[m
[32m+[m	[32mu64 stack_base;[m
[32m+[m	[32mu64 stack_size;[m
[32m+[m	[32mu64 prio;[m
[32m+[m[32m};[m
[32m+[m
[32m+[m[32m/* An example to launch an (libc) application process */[m
[32m+[m
[32m+[m[32m#define AT_NULL 0		/* end of vector */[m
[32m+[m[32m#define AT_IGNORE 1		/* entry should be ignored */[m
[32m+[m[32m#define AT_EXECFD 2		/* file descriptor of program */[m
[32m+[m[32m#define AT_PHDR 3		/* program headers for program */[m
[32m+[m[32m#define AT_PHENT 4		/* size of program header entry */[m
[32m+[m[32m#define AT_PHNUM 5		/* number of program headers */[m
[32m+[m[32m#define AT_PAGESZ 6		/* system page size */[m
[32m+[m[32m#define AT_BASE 7		/* base address of interpreter */[m
[32m+[m[32m#define AT_FLAGS 8		/* flags */[m
[32m+[m[32m#define AT_ENTRY 9		/* entry point of program */[m
[32m+[m[32m#define AT_NOTELF 10		/* program is not ELF */[m
[32m+[m[32m#define AT_UID 11		/* real uid */[m
[32m+[m[32m#define AT_EUID 12		/* effective uid */[m
[32m+[m[32m#define AT_GID 13		/* real gid */[m
[32m+[m[32m#define AT_EGID 14		/* effective gid */[m
[32m+[m[32m#define AT_PLATFORM 15		/* string identifying CPU for optimizations */[m
[32m+[m[32m#define AT_HWCAP 16		/* arch dependent hints at CPU capabilities */[m
[32m+[m[32m#define AT_CLKTCK 17		/* frequency at which times() increments */[m
[32m+[m[32m/* AT_* values 18 through 22 are reserved */[m
[32m+[m[32m#define AT_SECURE 23		/* secure mode boolean */[m
[32m+[m[32m#define AT_BASE_PLATFORM                                                       \[m
[32m+[m	[32m24			/* string identifying real platform, may                  \[m
[32m+[m				[32m * differ from AT_PLATFORM. */[m
[32m+[m[32m#define AT_RANDOM 25		/* address of 16 random bytes */[m
[32m+[m[32m#define AT_HWCAP2 26		/* extension of AT_HWCAP */[m
[32m+[m
[32m+[m[32m#define AT_EXECFN 31		/* filename of program */[m
[32m+[m
[32m+[m[32m#define NO_AFF -1[m
[32m+[m
[32m+[m[32mchar init_env[PAGE_SIZE];[m
[32m+[m[32mconst char PLAT[] = "aarch64";[m
[32m+[m
[32m+[m[32mstatic void construct_init_env(char *env, u64 top_vaddr,[m
[32m+[m			[32m       struct process_metadata *meta, char *name,[m
[32m+[m			[32m       struct pmo_map_request *pmo_map_reqs,[m
[32m+[m			[32m       int nr_pmo_map_reqs, int caps[], int nr_caps)[m
[32m+[m[32m{[m
[32m+[m	[32mint i, j;[m
[32m+[m	[32mchar *name_str;[m
[32m+[m	[32mchar *plat_str;[m
[32m+[m	[32mu64 *buf;[m
[32m+[m
[32m+[m	[32mint argc = 1;		/* at least 1 for binary name */[m
[32m+[m
[32m+[m	[32m/* clear init_env */[m
[32m+[m	[32mfor (i = 0; i < PAGE_SIZE; ++i) {[m
[32m+[m		[32menv[i] = 0;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m/* strings */[m
[32m+[m	[32m/* the last 64 bytes */[m
[32m+[m	[32mname_str = env + PAGE_SIZE - 64;[m
[32m+[m	[32mi = 0;[m
[32m+[m	[32mwhile (name[i] != '\0') {[m
[32m+[m		[32mname_str[i] = name[i];[m
[32m+[m		[32m++i;[m
[32m+[m	[32m}[m
[32m+[m	[32m// printf("name_str: %s\n", name_str);[m
[32m+[m
[32m+[m	[32m/* the second last 64 bytes */[m
[32m+[m	[32mplat_str = env + PAGE_SIZE - 2 * 64;[m
[32m+[m	[32mi = 0;[m
[32m+[m	[32mwhile (PLAT[i] != '\0') {[m
[32m+[m		[32mplat_str[i] = PLAT[i];[m
[32m+[m		[32m++i;[m
[32m+[m	[32m}[m
[32m+[m	[32m// printf("plat_str: %s\n", plat_str);[m
[32m+[m
[32m+[m	[32mbuf = (u64 *) env;[m
[32m+[m	[32m/* argc */[m
[32m+[m	[32m*buf = argc;[m
[32m+[m
[32m+[m	[32m/* argv */[m
[32m+[m	[32m*(buf + 1) = top_vaddr - 64;[m
[32m+[m	[32m/* add more argv here */[m
[32m+[m	[32m*(buf + 2) = (u64) NULL;[m
[32m+[m
[32m+[m	[32m/* envp */[m
[32m+[m	[32mi = 3;[m
[32m+[m	[32m/*[m
[32m+[m	[32m * e.g.,[m
[32m+[m	[32m * info_page_vaddr = (u64)envp[0];[m
[32m+[m	[32m * fs_server_cap = (u64)envp[1];[m
[32m+[m	[32m */[m
[32m+[m	[32mif (nr_pmo_map_reqs == 0) {[m
[32m+[m		[32m/* set info_page_vaddr to 0x0 */[m
[32m+[m		[32m*(buf + i) = (u64) 0;[m
[32m+[m		[32mi = i + 1;[m
[32m+[m	[32m} else {[m
[32m+[m		[32mfor (j = 0; j < nr_pmo_map_reqs; ++j) {[m
[32m+[m			[32m*(buf + i + j) = (u64) pmo_map_reqs[j].addr;[m
[32m+[m		[32m}[m
[32m+[m		[32mi = i + j;[m
[32m+[m	[32m}[m
[32m+[m	[32mfor (j = 0; j < nr_caps; ++j) {[m
[32m+[m		[32m/* e.g., fs_server_cap = (u64)envp[1]; */[m
[32m+[m		[32m*(buf + i + j) = (u64) caps[j];[m
[32m+[m	[32m}[m
[32m+[m	[32mi = i + j;[m
[32m+[m	[32m/* add more envp here */[m
[32m+[m	[32m*(buf + i) = (u64) NULL;[m
[32m+[m
[32m+[m	[32m/* auxv */[m
[32m+[m	[32mi = i + 1;[m
[32m+[m	[32m*(buf + i + 0) = AT_SECURE;[m
[32m+[m	[32m*(buf + i + 1) = 0;[m
[32m+[m
[32m+[m	[32m*(buf + i + 2) = AT_PAGESZ;[m
[32m+[m	[32m*(buf + i + 3) = PAGE_SIZE;[m
[32m+[m
[32m+[m	[32m*(buf + i + 4) = AT_PHDR;[m
[32m+[m	[32m*(buf + i + 5) = meta->phdr_addr;[m
[32m+[m
[32m+[m	[32m// printf("phdr_addr is 0x%lx\n", meta->phdr_addr);[m
[32m+[m
[32m+[m	[32m*(buf + i + 6) = AT_PHENT;[m
[32m+[m	[32m*(buf + i + 7) = meta->phentsize;[m
[32m+[m
[32m+[m	[32m*(buf + i + 8) = AT_PHNUM;[m
[32m+[m	[32m*(buf + i + 9) = meta->phnum;[m
[32m+[m
[32m+[m	[32m*(buf + i + 10) = AT_FLAGS;[m
[32m+[m	[32m*(buf + i + 11) = meta->flags;[m
[32m+[m
[32m+[m	[32m*(buf + i + 12) = AT_ENTRY;[m
[32m+[m	[32m*(buf + i + 13) = meta->entry;[m
[32m+[m
[32m+[m	[32m*(buf + i + 14) = AT_UID;[m
[32m+[m	[32m*(buf + i + 15) = 1000;[m
[32m+[m
[32m+[m	[32m*(buf + i + 16) = AT_EUID;[m
[32m+[m	[32m*(buf + i + 17) = 1000;[m
[32m+[m
[32m+[m	[32m*(buf + i + 18) = AT_GID;[m
[32m+[m	[32m*(buf + i + 19) = 1000;[m
[32m+[m
[32m+[m	[32m*(buf + i + 20) = AT_EGID;[m
[32m+[m	[32m*(buf + i + 21) = 1000;[m
[32m+[m
[32m+[m	[32m*(buf + i + 22) = AT_CLKTCK;[m
[32m+[m	[32m*(buf + i + 23) = 100;[m
[32m+[m
[32m+[m	[32m*(buf + i + 24) = AT_HWCAP;[m
[32m+[m	[32m*(buf + i + 25) = 0;[m
[32m+[m
[32m+[m	[32m*(buf + i + 25) = AT_PLATFORM;[m
[32m+[m	[32m*(buf + i + 26) = top_vaddr - 64 * 2;[m
[32m+[m
[32m+[m	[32m*(buf + i + 27) = AT_RANDOM;[m
[32m+[m	[32m*(buf + i + 28) = top_vaddr - 64;	/* random 16 bytes */[m
[32m+[m
[32m+[m	[32m*(buf + i + 29) = AT_NULL;[m
[32m+[m	[32m*(buf + i + 30) = 0;[m
[32m+[m
[32m+[m	[32m/* add more auxv here */[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#define MAX_NR_CAPS 16[m
[32m+[m[32m/*[m
[32m+[m[32m * Lab4[m
[32m+[m[32m * The core function used by spawn[m
[32m+[m[32m * user_elf: elf struct[m
[32m+[m[32m * child_process_cap: if not NULL, set to child_process_cap that can be[m
[32m+[m[32m *                    used in current process.[m
[32m+[m[32m *[m
[32m+[m[32m * child_main_thread_cap: if not NULL, set to child_main_thread_cap[m
[32m+[m[32m *                        that can be used in current process.[m
[32m+[m[32m *[m
[32m+[m[32m * pmo_map_reqs, nr_pmo_map_reqs: input pmos to map in the new process[m
[32m+[m[32m *[m
[32m+[m[32m * caps, nr_caps: copy from farther process to child process[m
[32m+[m[32m *[m
[32m+[m[32m * aff: affinity[m
[32m+[m[32m *[m
[32m+[m[32m */[m
[32m+[m[32m#define LAB4_SPAWN_BLANK 0[m
[32m+[m[32mint launch_process_with_pmos_caps(struct user_elf *user_elf,[m
[32m+[m				[32m  int *child_process_cap,[m
[32m+[m				[32m  int *child_main_thread_cap,[m
[32m+[m				[32m  struct pmo_map_request *pmo_map_reqs,[m
[32m+[m				[32m  int nr_pmo_map_reqs, int caps[], int nr_caps,[m
[32m+[m				[32m  s32 aff)[m
[32m+[m[32m{[m
[32m+[m	[32mint new_process_cap;[m
[32m+[m	[32mint main_thread_cap;[m
[32m+[m	[32mint ret;[m
[32m+[m
[32m+[m	[32mlong pc;[m
[32m+[m
[32m+[m	[32m/* for creating pmos */[m
[32m+[m	[32mstruct pmo_request pmo_requests[1];[m
[32m+[m	[32mint main_stack_cap;[m
[32m+[m	[32mu64 stack_offset;[m
[32m+[m	[32mu64 stack_top;[m
[32m+[m	[32mu64 stack_va;[m
[32m+[m	[32mu64 p_vaddr;[m
[32m+[m	[32mint i;[m
[32m+[m	[32m/* for mapping pmos */[m
[32m+[m	[32mstruct pmo_map_request pmo_map_requests[1];[m
[32m+[m	[32mint transfer_caps[MAX_NR_CAPS];[m
[32m+[m	[32m// Lab4 useless code, help avoid compile warning, you can delete it as you wish[m
[32m+[m	[32mtransfer_caps[0] = 0;[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m *  Step 1: create a new process with an empty vmspace[m[41m [m
[32m+[m		[32m *  You do not need to modify code in this scope[m
[32m+[m		[32m */[m
[32m+[m		[32mnew_process_cap = usys_create_process();[m
[32m+[m		[32mif (new_process_cap < 0) {[m
[32m+[m			[32mprintf("%s: fail to create new_process_cap (ret: %d)\n",[m
[32m+[m			[32m       __func__, new_process_cap);[m
[32m+[m			[32mgoto fail;[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m *  Step 2:[m[41m [m
[32m+[m		[32m *  Map each segment in the elf binary to child process[m
[32m+[m		[32m *  You do not need to modify code in this scope[m
[32m+[m		[32m */[m
[32m+[m		[32mfor (i = 0; i < 2; ++i) {[m
[32m+[m			[32mp_vaddr = user_elf->user_elf_seg[i].p_vaddr;[m
[32m+[m			[32mret = usys_map_pmo(new_process_cap,[m
[32m+[m					[32m   user_elf->user_elf_seg[i].elf_pmo,[m
[32m+[m					[32m   ROUND_DOWN(p_vaddr, PAGE_SIZE),[m
[32m+[m					[32m   user_elf->user_elf_seg[i].flags);[m
[32m+[m
[32m+[m			[32mif (ret < 0) {[m
[32m+[m				[32mprintf("usys_map_pmo ret %d\n", ret);[m
[32m+[m				[32musys_exit(-1);[m
[32m+[m			[32m}[m
[32m+[m		[32m}[m
[32m+[m		[32mpc = user_elf->elf_meta.entry;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m[41m [m
[32m+[m		[32m * Step 3:[m
[32m+[m		[32m * create pmo for the stack of main thread stack in current[m
[32m+[m		[32m * process.[m
[32m+[m		[32m *  You do not need to modify code in this scope[m
[32m+[m		[32m */[m
[32m+[m		[32mpmo_requests[0].size = LAB4_SPAWN_BLANK;[m
[32m+[m		[32mpmo_requests[0].type = LAB4_SPAWN_BLANK;[m
[32m+[m
[32m+[m		[32mret = usys_create_pmos((void *)pmo_requests, 1);[m
[32m+[m		[32mif (ret != 0) {[m
[32m+[m			[32mprintf("%s: fail to create_pmos (ret: %d)\n", __func__,[m
[32m+[m			[32m       ret);[m
[32m+[m			[32mgoto fail;[m
[32m+[m		[32m}[m
[32m+[m
[32m+[m		[32m/* get result caps */[m
[32m+[m		[32mmain_stack_cap = pmo_requests[0].ret_cap;[m
[32m+[m		[32mif (main_stack_cap < 0) {[m
[32m+[m			[32mprintf("%s: fail to create_pmos (ret: %d)\n", __func__,[m
[32m+[m			[32m       ret);[m
[32m+[m			[32mgoto fail;[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Step A :[m
[32m+[m		[32m * Transfer the capbilities (nr_caps) of current process to the[m
[32m+[m		[32m * capbilities of child process[m
[32m+[m		[32m */[m
[32m+[m
[32m+[m		[32mif (nr_caps > 0) {[m
[32m+[m			[32m/* usys_transfer_caps is used during process creation */[m
[32m+[m			[32mret = usys_transfer_caps(new_process_cap, caps, nr_caps,[m
[32m+[m						[32m transfer_caps);[m
[32m+[m			[32mif (ret != 0) {[m
[32m+[m				[32mprintf("usys_transfer_caps ret %d\n", ret);[m
[32m+[m				[32musys_exit(-1);[m
[32m+[m			[32m}[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Step B :[m
[32m+[m		[32m * Use the given pmo_mao_reqs to map the vmspace in the child[m
[32m+[m		[32m * process[m
[32m+[m		[32m */[m
[32m+[m		[32mif (nr_pmo_map_reqs) {[m
[32m+[m			[32mret =[m
[32m+[m			[32m    usys_map_pmos(new_process_cap, (void *)pmo_map_reqs,[m
[32m+[m					[32m  nr_pmo_map_reqs);[m
[32m+[m			[32mif (ret != 0) {[m
[32m+[m				[32mprintf("%s: fail to map_pmos (ret: %d)\n",[m
[32m+[m				[32m       __func__, ret);[m
[32m+[m				[32mgoto fail;[m
[32m+[m			[32m}[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Step 4[m
[32m+[m		[32m * Prepare the arguments in the top page of the main thread's[m
[32m+[m		[32m * stack.[m
[32m+[m		[32m * You should calculate the correct value of stack_top and[m
[32m+[m		[32m * stack_offset[m
[32m+[m		[32m */[m
[32m+[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Hints: refer to <defs.h>[m
[32m+[m		[32m * For stack_top, what's the virtual address of top of the main[m
[32m+[m		[32m * thread's stack?[m
[32m+[m		[32m *[m
[32m+[m		[32m * For stack_offset, when the main thread gets[m
[32m+[m		[32m * to execute the first time, what's the virtual adress the sp[m
[32m+[m		[32m * register points to?[m
[32m+[m		[32m * stack_offset is the offset from main thread's stack base to[m
[32m+[m		[32m * that address.[m
[32m+[m		[32m */[m
[32m+[m		[32mstack_top = LAB4_SPAWN_BLANK;[m
[32m+[m		[32mstack_offset = LAB4_SPAWN_BLANK;[m
[32m+[m
[32m+[m		[32m/* Construct the parameters on the top page of the stack */[m
[32m+[m		[32mconstruct_init_env(init_env, stack_top, &user_elf->elf_meta,[m
[32m+[m				[32m   user_elf->path, pmo_map_reqs,[m
[32m+[m				[32m   nr_pmo_map_reqs, transfer_caps, nr_caps);[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Step 5[m
[32m+[m		[32m * Update the main thread stack's pmo[m
[32m+[m		[32m * You only need to write the modified page[m
[32m+[m		[32m */[m
[32m+[m		[32mret = usys_write_pmo(main_stack_cap, stack_offset, init_env,[m
[32m+[m				[32m     PAGE_SIZE);[m
[32m+[m		[32mif (ret != 0) {[m
[32m+[m			[32mprintf("%s: fail to write_pmo (ret: %d)\n", __func__,[m
[32m+[m			[32m       ret);[m
[32m+[m			[32mgoto fail;[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Step 6[m
[32m+[m		[32m *  map the the main thread stack's pmo in the new process.[m
[32m+[m		[32m *  Both VM_READ and VM_WRITE permission should be set.[m
[32m+[m		[32m */[m
[32m+[m		[32mpmo_map_requests[0].pmo_cap = LAB4_SPAWN_BLANK;[m
[32m+[m		[32mpmo_map_requests[0].addr = LAB4_SPAWN_BLANK;[m
[32m+[m		[32mpmo_map_requests[0].perm = LAB4_SPAWN_BLANK;[m
[32m+[m
[32m+[m		[32mret =[m
[32m+[m		[32m    usys_map_pmos(new_process_cap, (void *)pmo_map_requests, 1);[m
[32m+[m
[32m+[m		[32mif (ret != 0) {[m
[32m+[m			[32mprintf("%s: fail to map_pmos (ret: %d)\n", __func__,[m
[32m+[m			[32m       ret);[m
[32m+[m			[32mgoto fail;[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/**[m
[32m+[m		[32m * Step 7[m
[32m+[m		[32m * create main thread in the new process.[m
[32m+[m		[32m * Please fill the stack_va![m
[32m+[m		[32m */[m
[32m+[m		[32mstack_va = LAB4_SPAWN_BLANK;[m
[32m+[m		[32mmain_thread_cap =[m
[32m+[m		[32m    usys_create_thread(new_process_cap, stack_va, pc,[m
[32m+[m				[32m       (u64) NULL, MAIN_THREAD_PRIO, aff);[m
[32m+[m		[32mif (main_thread_cap < 0) {[m
[32m+[m			[32mprintf("%s: fail to create thread (ret: %d)\n",[m
[32m+[m			[32m       __func__, ret);[m
[32m+[m			[32mgoto fail;[m
[32m+[m		[32m}[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32m{[m
[32m+[m		[32m/* Step C: Output the child process & thread capabilities */[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mreturn 0;[m
[32m+[m[32m fail:[m
[32m+[m	[32mreturn -EINVAL;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mint spawn(char *path, int *new_process_cap, int *new_thread_cap,[m
[32m+[m	[32m  struct pmo_map_request *pmo_map_reqs, int nr_pmo_map_reqs, int caps[],[m
[32m+[m	[32m  int nr_caps, int aff)[m
[32m+[m[32m{[m
[32m+[m	[32mstruct user_elf user_elf;[m
[32m+[m	[32mint ret;[m
[32m+[m
[32m+[m	[32mret = readelf_from_kernel_cpio(path, &user_elf);[m
[32m+[m	[32mif (ret < 0) {[m
[32m+[m		[32mprintf("[Client] Cannot create server.\n");[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32m}[m
[32m+[m
[32m+[m	[32mreturn launch_process_with_pmos_caps(&user_elf, new_process_cap,[m
[32m+[m					[32m     new_thread_cap, pmo_map_reqs,[m
[32m+[m					[32m     nr_pmo_map_reqs, caps, nr_caps,[m
[32m+[m					[32m     aff);[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/spawn.h b/user/lib/spawn.h[m
[1mnew file mode 100644[m
[1mindex 0000000..137f32d[m
[1m--- /dev/null[m
[1m+++ b/user/lib/spawn.h[m
[36m@@ -0,0 +1,8 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/launcher.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32mint spawn(char *path, int *new_process_cap, int *new_thread_cap,[m
[32m+[m	[32m  struct pmo_map_request *pmo_map_reqs, int nr_pmo_map_reqs, int caps[],[m
[32m+[m	[32m  int nr_caps, int aff);[m
[1mdiff --git a/user/lib/syscall.c b/user/lib/syscall.c[m
[1mindex 0bc95c9..ccf208d 100644[m
[1m--- a/user/lib/syscall.c[m
[1m+++ b/user/lib/syscall.c[m
[36m@@ -13,6 +13,21 @@[m [mu64 syscall(u64 sys_no, u64 arg0, u64 arg1, u64 arg2, u64 arg3, u64 arg4,[m
 	 * And finally use svc to execute the system call. After syscall returned, don't forget[m
 	 * to move return value from x0 to the ret variable of this function[m
 	 */[m
[32m+[m	[32masm volatile("mov x0, %1\n\t"[m
[32m+[m				[32m"mov x1, %2\n\t"[m
[32m+[m				[32m"mov x2, %3\n\t"[m
[32m+[m				[32m"mov x3, %4\n\t"[m
[32m+[m				[32m"mov x4, %5\n\t"[m
[32m+[m				[32m"mov x5, %6\n\t"[m
[32m+[m				[32m"mov x6, %7\n\t"[m
[32m+[m				[32m"mov x7, %8\n\t"[m
[32m+[m				[32m"mov x8, %9\n\t"[m
[32m+[m				[32m"svc #0\n\t"[m
[32m+[m				[32m"mov %0, x0\n\t"[m
[32m+[m				[32m: "=r" (ret)[m
[32m+[m				[32m: "r" (arg0), "r" (arg1), "r" (arg2), "r" (arg3), "r" (arg4), "r" (arg5), "r" (arg6), "r" (arg7), "r" (sys_no)[m
[32m+[m				[32m: "x0", "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8");[m
[32m+[m
 	return ret;[m
 }[m
 [m
[36m@@ -22,25 +37,27 @@[m [mu64 syscall(u64 sys_no, u64 arg0, u64 arg1, u64 arg2, u64 arg3, u64 arg4,[m
  */[m
 void usys_putc(char ch)[m
 {[m
[32m+[m	[32msyscall(SYS_putc, (u64) ch, 0, 0, 0, 0, 0, 0, 0, 0);[m
 }[m
 [m
 void usys_exit(int ret)[m
 {[m
[32m+[m	[32msyscall(SYS_exit, ret, 0, 0, 0, 0, 0, 0, 0, 0);[m
 }[m
 [m
 int usys_create_pmo(u64 size, u64 type)[m
 {[m
[31m-	return 0;[m
[32m+[m	[32mreturn (int) syscall(SYS_create_pmo, size, type, 0, 0, 0, 0, 0, 0, 0);[m
 }[m
 [m
 int usys_map_pmo(u64 process_cap, u64 pmo_cap, u64 addr, u64 rights)[m
 {[m
[31m-	return 0;[m
[32m+[m	[32mreturn (int) syscall(SYS_map_pmo, process_cap, pmo_cap, addr, rights, 0, 0, 0, 0, 0);[m
 }[m
 [m
 u64 usys_handle_brk(u64 addr)[m
 {[m
[31m-	return 0;[m
[32m+[m	[32mreturn syscall(SYS_handle_brk, addr, 0, 0, 0, 0, 0, 0, 0, 0);[m
 }[m
 [m
 /* Here finishes all syscalls need by lab3 */[m
[1mdiff --git a/user/lib/thread.c b/user/lib/thread.c[m
[1mnew file mode 100644[m
[1mindex 0000000..8b1fb95[m
[1m--- /dev/null[m
[1m+++ b/user/lib/thread.c[m
[36m@@ -0,0 +1,34 @@[m
[32m+[m[32m#include <lib/syscall.h>[m
[32m+[m[32m#include <lib/defs.h>[m
[32m+[m[32m#include <lib/print.h>[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32mint thread_num_in_process = 0;[m
[32m+[m
[32m+[m[32mint create_thread(void *(*func) (void *), u64 arg, u32 prio, s32 cpuid)[m
[32m+[m[32m{[m
[32m+[m	[32mint child_stack_pmo_cap = 0;[m
[32m+[m	[32mint child_thread_cap = 0;[m
[32m+[m	[32mint ret = 0;[m
[32m+[m
[32m+[m	[32mchild_stack_pmo_cap = usys_create_pmo(CHILD_THREAD_STACK_SIZE,[m
[32m+[m					[32m      PMO_ANONYM);[m
[32m+[m	[32mif (child_stack_pmo_cap < 0)[m
[32m+[m		[32mreturn child_stack_pmo_cap;[m
[32m+[m
[32m+[m	[32mret = usys_map_pmo(SELF_CAP,[m
[32m+[m			[32m   child_stack_pmo_cap,[m
[32m+[m			[32m   CHILD_THREAD_STACK_BASE +[m
[32m+[m			[32m   thread_num_in_process * CHILD_THREAD_STACK_SIZE,[m
[32m+[m			[32m   VM_READ | VM_WRITE);[m
[32m+[m	[32mif (ret < 0)[m
[32m+[m		[32mreturn ret;[m
[32m+[m	[32mthread_num_in_process += 1;[m
[32m+[m
[32m+[m	[32mchild_thread_cap = usys_create_thread(SELF_CAP, CHILD_THREAD_STACK_BASE[m
[32m+[m					[32m      +[m
[32m+[m					[32m      thread_num_in_process *[m
[32m+[m					[32m      CHILD_THREAD_STACK_SIZE,[m
[32m+[m					[32m      (u64) func, arg, prio, cpuid);[m
[32m+[m	[32mreturn child_thread_cap;[m
[32m+[m[32m}[m
[1mdiff --git a/user/lib/thread.h b/user/lib/thread.h[m
[1mnew file mode 100644[m
[1mindex 0000000..f837bac[m
[1m--- /dev/null[m
[1m+++ b/user/lib/thread.h[m
[36m@@ -0,0 +1,5 @@[m
[32m+[m[32m#pragma once[m
[32m+[m
[32m+[m[32m#include <lib/type.h>[m
[32m+[m
[32m+[m[32mint create_thread(void *(*func) (void *), u64 arg, u32 prio, s32 cpuid);[m
