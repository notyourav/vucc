(dotimes (i 32)
    (dolist (type '(B H W F))
        (let ((regname (format nil "r%d%t" i type)))
            (put (intern regname) 'regno (read-tree (substring regname 1 -1))))))
(put 'sp 'regno 3)
(put 'gp 'regno 4)
(put 'lp 'regno 31)

(defun get-regno (regsym)
    (get regsym 'regno))

(defun peephole-optimize (bblockh)
    (when (memq 'v810-peephole *optimize*)
        (when (memq 'peephole *debug*)
            (format t "=== v810-peephole\n")))
    (do-bblock (b bblockh)
        (peep-mcode (bblock-mcode b))))

(defun delete-mcode (m)
    (setq (mcode-next (mcode-prev m)) (mcode-next m) (mcode-prev (mcode-next m)) (mcode-prev m))
    (when (memq 'peephole *debug*)
        (format t "** %t DELETED\n" m))
    nil)

(defvar *z-flag-set-code*
    '(add addf.s addi and andi caxi cmp cmpf.s cvt.ws cvt.sw div divf.s divu ldsr mul mulf.s mulu not or ori reti sar sch0bsu sch0bsd shl shr sub subf.s trnc.sw xor xori))

(defvar *z-flag-reset-code*
    '(in.b in.h in.w ld.b ld.h ld.w mov movea movhi setf))

(defvar *z-flag-jmp-reset-code*
    '(jal jmp jmp-eq jmp-ne jmp-lt jmp-ltu jmp-le jmp-leu jmp-gt jmp-gtu jmp-ge jmp-geu))

(defun peep-mcode (mcodeh)
    (when (memq 'peephole *debug*)
        (format t "** block\n"))
    (let (zflag)
        (do-mcode (m mcodeh)
            (let ((code (mcode-code m)) (args (mcode-args m)))
                (when (memq 'peephole *debug*)
                    (format t "** %t\n" m))
                (cond ((eq code 'mov)
                             (and (symbol-p (car args))
                                        (symbol-p (cadr args))
                                        (eq (get-regno (car args))
                                                (get-regno (cadr args)))
                                        (delete-mcode m)))
                            ((eq code 'cmp)
                             (and (equal (car args) '(i4 0))
                                        (eq zflag (get-regno (cadr args)))
                                        (delete-mcode m))))
                (cond ((memq code *z-flag-set-code*)
                             (setq zflag (z-flag-set-code code args)))
                            ((memq code *z-flag-jmp-reset-code*)
                             (setq zflag nil))
                            ((memq code *z-flag-reset-code*)
                             (and (eq zflag (z-flag-reset-code code args))
                                        (setq zflag nil))))))))
                             
(defun z-flag-set-code (code args)
    (ecase code
        ((add addf.s and caxi cmp cmpf.s cvt.ws cvt.sw div divf.s divu ldsr mul mulf.s mulu not or ori sar shl shr sub subf.s trnc.sw xor)
         (get-regno (cadr args)))
        ((addi andi xori)
         (get-regno (caddr args)))
        ((sch0bsu sch0bsd reti)
         nil)))

(defun z-flag-reset-code (code args)
    (ecase code
        ((in.b in.h in.w ld.b ld.h ld.w mov movhi setf)
         (get-regno (cadr args)))
        ((movea)
         (get-regno (caddr args)))))