// SPDX-License-Identifier: BSD-2-Clause-Patent
#include <AsmMacroLib.h>

ASM_FUNC(DarwinCurrentEl)
  mrs x0, CurrentEL
  ret

// x0=boot_args PA, x1=entry PA, x2=owned PA, x3=owned size, x4=frame buffer
// PA (0 for none), x5=its size in bytes. EL1 only.
ASM_FUNC(DarwinEnter)
  msr daifset, #15
  // Preserve the framebuffer PA/size; x4/x5 are reused by the cache clean below.
  mov x8, x4            // framebuffer PA (0 = none)
  mov x9, x5            // framebuffer size in bytes
  // Clean the owned kernel window to the point of coherency while the MMU is
  // still on, so the physical RAM holds the freshly copied kernel image.
  add x5, x2, x3
  mrs x6, ctr_el0
  ubfx x6, x6, #16, #4
  mov x7, #4
  lsl x6, x7, x6
  sub x7, x6, #1
  bic x4, x2, x7
  dsb sy
1:
  dc civac, x4
  add x4, x4, x6
  cmp x4, x5
  b.lo 1b
  dsb sy
  ic iallu
  dsb sy
  isb
  // Turn the MMU off. From this point every address is physical.
  mrs x4, sctlr_el1
  bic x4, x4, #1
  bic x4, x4, #4
  bic x4, x4, #0x1000
  msr sctlr_el1, x4
  isb
  tlbi vmalle1
  dsb sy
  isb
  // Breadcrumb: a small green block at the top-left corner proves this code ran
  // and the MMU is off. Kept small so it does not cover the iPad home screen the
  // loader draws. It MUST be drawn now, not before the MMU was disabled:
  // Video[0] is the framebuffer PHYSICAL base (what the kernel wants in
  // boot_args), and writing it with the UEFI MMU on aborts on boards where
  // FrameBufferBase has no 1:1 virtual mapping (synchronous external abort).
  cbz x8, 2f
  mov x9, #8192
  mov w10, #0xFF00
  movk w10, #0xFF00, lsl #16
  mov x11, x8
3:
  stp w10, w10, [x11], #8
  subs x9, x9, #8
  b.hi 3b
  dsb sy
2:
  br x1
