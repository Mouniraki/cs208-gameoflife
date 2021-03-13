    ;;    game state memory location
    .equ CURR_STATE, 0x1000              ; current game state
    .equ GSA_ID, 0x1004                     ; gsa currently in use for drawing
    .equ PAUSE, 0x1008                     ; is the game paused or running
    .equ SPEED, 0x100C                      ; game speed
    .equ CURR_STEP,  0x1010              ; game current step
    .equ SEED, 0x1014              ; game seed
    .equ GSA0, 0x1018              ; GSA0 starting address
    .equ GSA1, 0x1038              ; GSA1 starting address
    .equ SEVEN_SEGS, 0x1198             ; 7-segment display addresses
    .equ CUSTOM_VAR_START, 0x1200 ; Free range of addresses for custom variable definition
    .equ CUSTOM_VAR_END, 0x1300
    .equ LEDS, 0x2000                       ; LED address
    .equ RANDOM_NUM, 0x2010          ; Random number generator address
    .equ BUTTONS, 0x2030                 ; Buttons addresses

    ;; states
    .equ INIT, 0
    .equ RAND, 1
    .equ RUN, 2

    ;; constants
    .equ N_SEEDS, 4
    .equ N_GSA_LINES, 8
    .equ N_GSA_COLUMNS, 12
    .equ MAX_SPEED, 10
    .equ MIN_SPEED, 1
    .equ PAUSED, 0x00
    .equ RUNNING, 0x01

main:
	addi sp, zero, LEDS ;stack pointer initialization

	call reset_game
	call get_input
	add a0, zero, v0
	add t0, zero, zero ;done variable

	while_ndone_loop:
		call push_temps_on_stack
		call select_action
		call pull_temps_from_stack

		call push_temps_on_stack
		call update_state
		call pull_temps_from_stack

		call push_temps_on_stack
		call update_gsa
		call pull_temps_from_stack		

		call push_temps_on_stack
		call mask
		call pull_temps_from_stack

		call push_temps_on_stack
		call draw_gsa
		call pull_temps_from_stack

		call push_temps_on_stack
		call wait
		call pull_temps_from_stack
		
		call push_temps_on_stack
		call decrement_step
		call pull_temps_from_stack
		add t0, zero, v0		

		call push_temps_on_stack
		call get_input
		call pull_temps_from_stack
		add a0, zero, v0
		beq t0, zero, while_ndone_loop
		jmpi main
		;;TODO


;BEGIN:helper
push_temps_on_stack:
	addi sp, sp, -44
	stw t0, 40(sp)
	stw t1, 36(sp)
	stw t2, 32(sp)
	stw t3, 28(sp)
	stw t4, 24(sp)
	stw t5, 20(sp)
	stw t6, 16(sp)
	stw t7, 12(sp)
	stw a0, 8(sp)
	stw a1, 4(sp)
	stw a2, 0(sp)	
	ret
pull_temps_from_stack:	
	ldw a2, 0(sp)
	ldw a1, 4(sp)
	ldw a0, 8(sp)
	ldw t7, 12(sp)
	ldw t6, 16(sp)
	ldw t5, 20(sp)
	ldw t4, 24(sp)
	ldw t3, 28(sp)
	ldw t2, 32(sp)
	ldw t1, 36(sp)
	ldw t0, 40(sp)
	addi sp, sp, 44
	ret
;END:helper


;----------
;PART 3.1:
;----------
;BEGIN:clear_leds
clear_leds:
	stw zero, LEDS(zero)
	addi t0, zero, 4
	stw zero, LEDS(t0)
	addi t0, t0, 4
	stw zero, LEDS(t0)
	ret
;END:clear_leds

; BEGIN:set_pixel
set_pixel:
	;a0 = x-coordinate
	;a1 = y-coordinate
	srli t0, a0, 2 ;integer division by 4 to get the correct LED vector index
	slli t0, t0, 2 ;multiplying it by 4 (addresses byte-aligned)
	ldw t1, LEDS(t0) ;taking the correct LEDS vector
	
	;formula : 8*x + y
	andi a0, a0, 3 ;taking a0 mod 4
	add t2, zero, a0
	slli t2, t2, 3
	add t2, t2, a1
	
	addi t3, zero, 1 ;creating a bit vector
	sll t3, t3, t2 ;placing the (x, y) bit appropriately

	or t1, t1, t3 ;appending the representation of LEDS(x) with the generated bit vector
	stw t1, LEDS(t0) ;storing it
	ret
;END:set_pixel

;BEGIN:wait
wait:
	addi t0, zero, 1
	slli t0, t0, 22 ;2^19
	ldw t1, SPEED(zero)
	
	delay_loop:
		sub t0, t0, t1
		blt zero, t0, delay_loop
	ret
;END:wait


;---------
;PART 3.2:
;---------
;BEGIN:get_gsa
get_gsa:
	slli t0, a0, 2 ;getting the correct index
	ldw t1, GSA_ID(zero) ;storing the GSA ID
	beq t1, zero, get_from_gsa0 ;if GSA_ID == 0, we retrieve from GSA0
	jmpi get_from_gsa1 ;else, we retrieve from GSA1
	get_from_gsa0: ldw v0, GSA0(t0)
	ret
	get_from_gsa1: ldw v0, GSA1(t0)
	ret
;END:get_gsa

;BEGIN:set_gsa
set_gsa:
	slli t0, a1, 2 ;getting the correct index
	ldw t1, GSA_ID(zero) ;storing the GSA ID
	beq t1, zero, set_in_gsa0 ;if GSA_ID == 0, we store in GSA0
	jmpi set_in_gsa1 ;else, we store in GSA1
	set_in_gsa0: stw a0, GSA0(t0)
	ret
	set_in_gsa1: stw a0, GSA1(t0)
	ret
;END:set_gsa


;--------
;PART 3.3
;--------
;BEGIN:draw_gsa
draw_gsa:
	addi sp, sp, -4
	stw ra, 0(sp)

	add t0, zero, zero ;LEDS[0]
	add t1, zero, zero ;LEDS[1]
	add t2, zero, zero ;LEDS[2]

	add a0, zero, zero ;y-coordinate for GSA line (for get_gsa)

	loop_retrieve_gsa_lines:
		call push_temps_on_stack
		call get_gsa ;v0 = line at y-coordinate in GSA
		call pull_temps_from_stack
		add t3, zero, v0
	
		add t4, zero, zero ;x-index
		addi t7, zero, 4 ;max-treshold of x-coordinate to switch to LEDS[1]
		loop_on_LEDS_0:
			andi t5, t4, 3
			slli t5, t5, 3 ;multiplying by 8 to retrieve the correct LEDS[0] index
			add t5, t5, a0 ;adding the y-coordinate value to it
			srl t6, t3, t4 ;isolating the GSA bit at position x (=t4)
			andi t6, t6, 1 ;extracting it
			sll t6, t6, t5 ;positioning the bit to the correct position
			or t0, t0, t6 ;appending it to LEDS[0]
			addi t4, t4, 1 ;incrementing the x-coordinate value
			blt t4, t7, loop_on_LEDS_0
		 
		addi t7, zero, 8 ;max-treshold of x-coordinate to switch to LEDS[2]
		loop_on_LEDS_1:
			andi t5, t4, 3
			slli t5, t5, 3 ;multiplying by 8 to retrieve the correct LEDS[1] index
			add t5, t5, a0 ;adding the y-coordinate value to it
			srl t6, t3, t4 ;isolating the GSA bit at position x (=t4)
			andi t6, t6, 1 ;extracting it
			sll t6, t6, t5 ;positioning the bit to the correct position
			or t1, t1, t6 ;appending it to LEDS[1]
			addi t4, t4, 1 ;incrementing the x-coordinate value
			blt t4, t7, loop_on_LEDS_1
	
		addi t7, zero, N_GSA_COLUMNS ;max-treshold of x-coordinate to stop
		loop_on_LEDS_2:
			andi t5, t4, 3
			slli t5, t5, 3 ;multiplying by 8 to retrieve the correct LEDS[2] index
			add t5, t5, a0 ;adding the y-coordinate value to it
			srl t6, t3, t4 ;isolating the GSA bit at position x (=t4)
			andi t6, t6, 1 ;extracting it
			sll t6, t6, t5 ;positioning the bit to the correct position
			or t2, t2, t6 ;appending it to LEDS[2]
			addi t4, t4, 1 ;incrementing the x-coordinate value
			blt t4, t7, loop_on_LEDS_2
		
		addi t7, zero, N_GSA_LINES
		addi a0, a0, 1 ;incrementing the y-coordinate
		blt a0, t7, loop_retrieve_gsa_lines
	
	stw t0, LEDS(zero) ;writing LEDS[0]
	addi t7, zero, 4
	stw t1, LEDS(t7) ;writing LEDS[1]
	addi t7, t7, 4
	stw t2, LEDS(t7) ;writing LEDS[2]

	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
;END:draw_gsa


;--------
;PART 3.4
;--------
;BEGIN:random_gsa
random_gsa:
	add a1, zero, zero ;y-coordinate where to write
	addi t1, zero, N_GSA_LINES ;total number of GSA lines (loop condition)
	
	apply_random_in_gsa:
		ldw t0, RANDOM_NUM(zero) ;1RANDOM = 1GSA LINE
		andi t0, t0, 0xFFF
		add a0, zero, t0 ;value to write in GSA
		addi sp, sp, -4
		stw ra, 0(sp)
		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack
		ldw ra, 0(sp)
		addi sp, sp, 4
		addi a1, a1, 1
		blt a1, t1, apply_random_in_gsa
	ret
;END:random_gsa


;--------
;PART 3.5
;--------
;BEGIN:change_speed
change_speed:
	ldw t0, SPEED(zero)
	addi t1, zero, MIN_SPEED
	addi t2, zero, MAX_SPEED
	bne a0, zero, decrement_condition
	jmpi increment_condition
	
	decrement_condition: 
		blt t1, t0, decrement_game_speed
		ret
	increment_condition: 
		blt t0, t2, increment_game_speed
		ret

	decrement_game_speed: 
		addi t0, t0, -1
		stw t0, SPEED(zero)
		ret
	increment_game_speed: 
		addi t0, t0, 1
		stw t0, SPEED(zero)
		ret
;END:change_speed

;BEGIN:pause_game
pause_game:
	ldw t0, PAUSE(zero)
	beq t0, zero, switch_to_play
	switch_to_pause:
		addi t0, zero, PAUSED
		stw t0, PAUSE(zero)
		ret

	switch_to_play:
		addi t0, zero, RUNNING
		stw t0, PAUSE(zero)
		ret
;END:pause_game

;BEGIN:change_steps
change_steps:
	;original value of current step
	ldw t0, CURR_STEP(zero)
	slli a0, a0, 0	;units
	slli a1, a1, 4	;tens
	slli a2, a2, 8	;hundreds
	
	add t0, t0, a0
	add t0, t0, a1
	add t0, t0, a2
	andi t0, t0, 0xFFF ;mod FFF
	stw t0, CURR_STEP(zero)

	andi t1, t0, 0xF ;extracting units
	andi t2, t0, 0xF0 ;extracting tens
	andi t3, t0, 0xF00 ;extracting hundreds
	
	;writing on the 7SEGS
	slli t1, t1, 2 ;units
	srli t2, t2, 2 ;tens
	srli t3, t3, 6 ;hundreds
	
	addi t0, zero, 4
	ldw t4, font_data(t3)
	stw t4, SEVEN_SEGS(t0)

	addi t0, t0, 4
	ldw t4, font_data(t2)
	stw t4, SEVEN_SEGS(t0)

	addi t0, t0, 4
	ldw t4, font_data(t1)
	stw t4, SEVEN_SEGS(t0)
	ret
;END:change_steps

;BEGIN:increment_seed
increment_seed:
	ldw t0, CURR_STATE(zero)
	addi t1, zero, INIT
	beq t0, t1, init_actions
	addi t1, zero, RAND
	beq t0, t1, rand_actions
	ret

	init_actions:
		ldw t0, SEED(zero)
		addi t2, zero, N_SEEDS
		bge t0, t2, rand_actions

		addi t0, t0, 1 ;incrementing the current seed by 1
		stw t0, SEED(zero)
		beq t0, t2, rand_actions ;if we just incremented to 4, we don't want to display a preregistered seed
	
		slli t0, t0, 2
		ldw t1, SEEDS(t0)
		addi t2, zero, N_GSA_LINES
		add a1, zero, zero ;reset the line index to 0
		set_new_seed_loop:
			ldw a0, 0(t1) ;loading the correct seed line
			addi sp, sp, -4
			stw ra, 0(sp)
			call push_temps_on_stack
			call set_gsa ;storing it in the GSA
			call pull_temps_from_stack
			ldw ra, 0(sp)
			addi sp, sp, 4
			addi t1, t1, 4
			addi a1, a1, 1
			blt a1, t2, set_new_seed_loop
			ret
		
	rand_actions:
		addi sp, sp, -4
		stw ra, 0(sp)
		call random_gsa ;generates a random GSA
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
;END:increment_seed

;BEGIN:update_state
update_state:
	ldw t0, CURR_STATE(zero)
	addi t1, zero, INIT
	beq t0, t1, transitions_from_init
	addi t1, zero, RAND
	beq t0, t1, transitions_from_rand
	addi t1, zero, RUN
	beq t0, t1, transitions_from_run

	transitions_from_init:
		ldw t0, SEED(zero)
		addi t1, zero, N_SEEDS
		beq t0, t1, transition_to_rand
		
		andi t0, a0, 31
		addi t1, zero, 2 ;button1 value
		beq t0, t1, transition_to_run
		ret

	transitions_from_rand:
		andi t0, a0, 31
		addi t1, zero, 2 ;button1 value
		beq t0, t1, transition_to_run
		ret

	transitions_from_run:
		andi t0, a0, 31
		addi t1, zero, 8 ;button3 value
		beq t0, t1, transition_to_init
		ldw t0, CURR_STEP(zero)
		beq t0, zero, transition_to_init
		ret

	transition_to_init:
		addi t0, zero, INIT
		stw t0, CURR_STATE(zero)
		addi sp, sp, -4
		stw ra, 0(sp)
		call reset_game
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	transition_to_rand:
		addi t0, zero, RAND
		stw t0, CURR_STATE(zero)	
		ret
	transition_to_run:
		addi t0, zero, RUN
		stw t0, CURR_STATE(zero)
		addi sp, sp, -4
		stw ra, 0(sp)
		call pause_game
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
;END:update_state

;BEGIN:select_action
select_action:
	ldw t0, CURR_STATE(zero)
	addi t1, zero, INIT
	beq t0, t1, button_action_on_init_rand_state
	addi t1, zero, RAND
	beq t0, t1, button_action_on_init_rand_state
	addi t1, zero, RUN
	beq t0, t1, button_action_on_run_state

	button_action_on_init_rand_state:
		andi t0, v0, 31
		addi t1, zero, 1
		beq t0, t1, init_rand_action_on_button0
		addi t1, zero, 2
		beq t0, t1, init_rand_action_on_button1
		addi t1, zero, 4
		beq t0, t1, init_rand_action_on_button2
		addi t1, zero, 8
		beq t0, t1, init_rand_action_on_button3
		addi t1, zero, 16
		beq t0, t1, init_rand_action_on_button4
		ret
	
	init_rand_action_on_button0:
		addi sp, sp, -4
		stw ra, 0(sp)
		call push_temps_on_stack
		call increment_seed
		call pull_temps_from_stack
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret

	init_rand_action_on_button1:
		;addi sp, sp, -4
		;stw ra, 0(sp)
		;call push_temps_on_stack
		;call pause_game
		;call pull_temps_from_stack
		;ldw ra, 0(sp)
		;addi sp, sp, 4
		ret

	init_rand_action_on_button2:
		addi a2, zero, 1
		add a1, zero, zero
		add a0, zero, zero
		addi sp, sp, -4
		stw ra, 0(sp)
		call push_temps_on_stack
		call change_steps
		call pull_temps_from_stack
		ldw ra, 0(sp)
		addi sp, sp, 4
		add a2, zero, zero
		ret

	init_rand_action_on_button3:
		add a2, zero, zero
		addi a1, zero, 1
		add a0, zero, zero
		addi sp, sp, -4
		stw ra, 0(sp)
		call push_temps_on_stack
		call change_steps
		call pull_temps_from_stack
		ldw ra, 0(sp)
		addi sp, sp, 4
		add a1, zero, zero
		ret

	init_rand_action_on_button4:
		add a2, zero, zero
		add a1, zero, zero
		addi a0, zero, 1
		addi sp, sp, -4
		stw ra, 0(sp)
		call push_temps_on_stack
		call change_steps
		call pull_temps_from_stack
		ldw ra, 0(sp)
		addi sp, sp, 4
		add a0, zero, zero
		ret

	button_action_on_run_state:
		andi t0, v0, 31
		addi t1, zero, 1
		beq t0, t1, run_action_on_button0
		addi t1, zero, 2
		beq t0, t1, run_action_on_button1
		addi t1, zero, 4
		beq t0, t1, run_action_on_button2
		addi t1, zero, 8
		beq t0, t1, run_action_on_button3
		addi t1, zero, 16
		beq t0, t1, run_action_on_button4
		ret
	
	run_action_on_button0:
		addi sp, sp, -4
		stw ra, 0(sp)
		call pause_game
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	
	run_action_on_button1:
		add a0, zero, zero ;increments
		addi sp, sp, -4
		stw ra, 0(sp)
		call change_speed
		ldw ra, 0(sp)
		addi sp, sp, 4
		add a0, zero, zero
		ret

	run_action_on_button2:
		addi a0, zero, 1 ;decrements
		addi sp, sp, -4
		stw ra, 0(sp)
		call change_speed
		ldw ra, 0(sp)
		addi sp, sp, 4
		add a0, zero, zero
		ret

	run_action_on_button3:
		addi sp, sp, -4
		stw ra, 0(sp)
		call reset_game
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret

	run_action_on_button4:
		addi sp, sp, -4
		stw ra, 0(sp)
		call random_gsa
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
;END:select_action


;--------
;PART 3.6
;--------
;BEGIN:cell_fate
cell_fate:
	addi t0, zero, 2
	addi t1, zero, 3

	blt a0, t0, cell_underpop ; underpopulation situation -> cell dying
	blt t1, a0, cell_overpop ; overpopulation situation -> cell dying
	beq a0, t1, cell_reprod_stasis ; reproduction situation -> cell alive
	beq a0, t0, cell_stasis ; stasis situation -> cell keeping state
	ret

	cell_underpop:
		add v0, zero, zero
		ret
	cell_overpop:
		add v0, zero, zero
		ret
	cell_reprod_stasis:
		addi v0, zero, 1
		ret
	cell_stasis:
		add v0, zero, a1
		ret
;END:cell_fate


;BEGIN:find_neighbours
find_neighbours:
	addi sp, sp, -8
	stw ra, 4(sp)
	stw a0, 0(sp) ;storing the value of a0 in the stack (x-coordinate)

	;getting the top row
	beq a1, zero, goto_line_11
	addi a0, a1, -1
	jmpi continue_loading_1st_row
	goto_line_11: addi a0, zero, 11

	continue_loading_1st_row:
		call push_temps_on_stack
		call get_gsa
		call pull_temps_from_stack
		add t1, zero, v0 ;storing the top row in t1
		
	add a0, zero, a1 ;getting the value for the middle row
	call push_temps_on_stack
	call get_gsa
	call pull_temps_from_stack
	add t2, zero, v0 ;storing the middle row in t2

	;getting the bottom row
	addi t3, zero, 11
	beq a1, t3, goto_line_zero
	addi a0, a1, 1
	jmpi continue_loading_3rd_row
	goto_line_zero: add a0, zero, zero

	continue_loading_3rd_row:
		call push_temps_on_stack
		call get_gsa
		call pull_temps_from_stack
		add t3, zero, v0 ;storing the bottom row in t3
	
	ldw a0, 0(sp) ;retrieving the x-coordinate value
	addi sp, sp, 4

	add v0, zero, zero ;resetting the v0 register

	;FOR THE LEFT CELLS
	beq a0, zero, goto_cell_11
	addi t4, a0, -1
	jmpi continue_checking_left_cells
	goto_cell_11: addi t4, zero, 11
	continue_checking_left_cells:
		;for top row
		srl t5, t1, t4
		andi t5, t5, 1
		add v0, v0, t5

		;for middle row
		srl t5, t2, t4
		andi t5, t5, 1
		add v0, v0, t5

		;for bottom_row
		srl t5, t3, t4
		andi t5, t5, 1
		add v0, v0, t5

	;FOR THE MIDDLE CELLS
	add t4, a0, zero
	check_for_middle_cells:
		;for top row
		srl t5, t1, t4
		andi t5, t5, 1
		add v0, v0, t5

		;for middle row
		srl t5, t2, t4
		andi t5, t5, 1
		add v1, zero, t5

		;for bottom_row
		srl t5, t3, t4
		andi t5, t5, 1
		add v0, v0, t5

	;FOR THE RIGHT CELLS
	addi t6, zero, 11
	beq a0, t6, goto_cell_zero
	addi t4, a0, 1
	jmpi continue_checking_right_cells
	goto_cell_zero: add t4, zero, zero
	continue_checking_right_cells:
		;for top row
		srl t5, t1, t4
		andi t5, t5, 1
		add v0, v0, t5

		;for middle row
		srl t5, t2, t4
		andi t5, t5, 1
		add v0, v0, t5

		;for bottom_row
		srl t5, t3, t4
		andi t5, t5, 1
		add v0, v0, t5

	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
;END:find_neighbours

;BEGIN:update_gsa
update_gsa:	
	ldw t0, PAUSE(zero)
	addi t1, zero, RUNNING
	beq t0, t1, do_update_gsa
	ret

	do_update_gsa:
		addi sp, sp, -4
		stw ra, 0(sp)
		add t0, zero, zero ;x-coordinate
		add t1, zero, zero ;y-coordinate
		ldw t2, GSA_ID(zero) ;getting the GSA_ID field
		
		addi t5, zero, N_GSA_LINES ;max value of y
		addi t6, zero, N_GSA_COLUMNS ;max value of x

		loop_on_y_coordinate:
			add t0, zero, zero ;resetting the x-coordinate pointer for the next calls
			add t4, zero, zero ;resetting the temp GSA line for the next calls
			loop_on_x_coordinate:
				add a0, zero, t0 ;setting the parameters for find_neighbours
				add a1, zero, t1
				call push_temps_on_stack
				call find_neighbours ;v0 = number of living neighbours / v1 = state of the (x, y) cell
				call pull_temps_from_stack
			
				add a0, zero, v0 ;setting the parameters for cell_fate
				add a1, zero, v1
				call push_temps_on_stack
				call cell_fate ;v0 = cell state
				call pull_temps_from_stack
			
				add t3, zero, v0 ;getting the cell value
				sll t3, t3, t0 ;shifting the value to place it accordingly in the new GSA
				
				or t4, t4, t3 ;placing it in a vector t4
				addi t0, t0, 1 ;incrementing the x-coordinate
				blt t0, t6, loop_on_x_coordinate

			ldw t7, GSA_ID(zero)
			xori t7, t7, 1
			stw t7, GSA_ID(zero)
			
			add a0, zero, t4 ;final value of the GSA line
			add a1, zero, t1 ;y-parameter of the GSA line
			call push_temps_on_stack
			call set_gsa
			call pull_temps_from_stack
			stw t2, GSA_ID(zero) ;reverting to original GSA_ID value for the next calls
			
			addi t1, t1, 1 ;incrementing the y-coordinate pointer
			blt t1, t5, loop_on_y_coordinate
			
		xori t2, t2, 1 ;inverting the current GSA
		stw t2, GSA_ID(zero) ;storing the inverted GSA

		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
;END:update_gsa


;BEGIN:mask
mask:
	addi sp, sp, -4
	stw ra, 0(sp)
	
	ldw t0, SEED(zero) ;loads the current seed
	slli t0, t0, 2 ;multiplying the value by 2 to retrieve the correct mask addresses
	ldw t1, MASKS(t0) ;getting the correct mask group
	add a1, zero, zero ;initializing the a1 parameter to 0 (for set_gsa)

	addi t3, zero, N_GSA_LINES
	masking_loop:
		add a0, zero, a1 ;to pass to get_gsa
		call push_temps_on_stack
		call get_gsa ;outputs the correct GSA line in v0
		call pull_temps_from_stack
		
		ldw t2, 0(t1) ;loading the corresponding mask work
		and a0, v0, t2 ;applying the mask
		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack
		
		addi a1, a1, 1 ;incrementing the GSA line y-coordinate by 1
		addi t1, t1, 4 ;incrementing the mask word address by 4 (to point to next)
		
		blt a1, t3, masking_loop
	
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
;END:mask

;--------
;PART 3.7
;--------
;BEGIN:get_input
get_input:
	addi t0, zero, 4
	ldw v0, BUTTONS(t0)
	stw zero, BUTTONS(t0)
	srli t2, v0, 5
	slli t2, t2, 5

	;button0
	check_for_button0:
		addi t3, zero, 1
		and t4, v0, t3
		bne t4, zero, append_button0
		jmpi check_for_button1
		append_button0: 
			or t2, t2, t4
			add v0, zero, t2
		ret

	;button1
	check_for_button1:
		addi t3, zero, 2
		and t4, v0, t3
		bne t4, zero, append_button1
		jmpi check_for_button2
		append_button1: 
			or t2, t2, t4
			add v0, zero, t2
		ret

	;button2
	check_for_button2:
		addi t3, zero, 4
		and t4, v0, t3
		bne t4, zero, append_button2
		jmpi check_for_button3
		append_button2: 
			or t2, t2, t4
			add v0, zero, t2
		ret

	;button3
	check_for_button3:
		addi t3, zero, 8
		and t4, v0, t3
		bne t4, zero, append_button3
		jmpi check_for_button4
		append_button3: 
			or t2, t2, t4
			add v0, zero, t2
		ret

	;button4
	check_for_button4:
		addi t3, zero, 16
		and t4, v0, t3
		bne t4, zero, append_button4
		ret
		append_button4: 
			or t2, t2, t4
			add v0, zero, t2
		ret
;END:get_input

;---------
;PART 3.8:
;---------
;BEGIN:decrement_step
decrement_step:
	ldw t0, CURR_STATE(zero)
	addi t1, zero, RUN
	beq t0, t1, check_game_paused
	check_game_paused:
		ldw t0, PAUSE(zero)
		bne t0, zero, check_current_step	
	add v0, zero, zero
	ret
	
	check_current_step:
		ldw t0, CURR_STEP(zero)
		beq t0, zero, returns_one
		addi t0, t0, -1
		stw t0, CURR_STEP(zero)

		;displaying the current step in the 7SEG
		andi t1, t0, 15 ;first 4 bits
		srli t0, t0, 4 ;discarding the bits
		andi t2, t0, 15 ;next 4 bits
		srli t0, t0, 4 ;discarting the bits
		andi t3, t0, 15 ;next 4 bits

		slli t1, t1, 2 ;index for SEVEN_SEGS[3] value
		slli t2, t2, 2 ;index for SEVEN_SEGS[2] value
		slli t3, t3, 2 ;index for SEVEN_SEGS[1] value

		addi t4, zero, 4
		ldw t5, font_data(t3)
		stw t5, SEVEN_SEGS(t4)

		addi t4, t4, 4
		ldw t5, font_data(t2)
		stw t5, SEVEN_SEGS(t4)
		
		addi t4, t4, 4
		ldw t5, font_data(t1)
		stw t5, SEVEN_SEGS(t4)
		
		;returning 0
		add v0, zero, zero
		ret

	returns_one: 
		addi v0, zero, 1
		ret
;END:decrement_step

;---------
;PART 3.9
;---------
;BEGIN:reset_game
reset_game:
	;first reset the LEDs
	addi sp, sp, -4
	stw ra, 0(sp)
	call clear_leds
	ldw ra, 0(sp)
	addi sp, sp, 4

	;current step is 1
	addi t0, zero, 1
	stw t0, CURR_STEP(zero)
	add t1, zero, zero

	;displaying it
	ldw t2, font_data(zero)
	stw t2, SEVEN_SEGS(t1)
	addi t1, t1, 4
	stw t2, SEVEN_SEGS(t1)
	addi t1, t1, 4
	stw t2, SEVEN_SEGS(t1)

	addi t3, zero, 4
	ldw t2, font_data(t3)
	addi t1, t1, 4
	stw t2, SEVEN_SEGS(t1)
	
	;seed 0 is selected
	add a1, zero, zero
	addi t0, zero, N_GSA_LINES

	set_seed0_in_gsa:
		add t1, zero, a1
		slli t1, t1, 2
		ldw a0, seed0(t1)
		addi sp, sp, -4
		stw ra, 0(sp)
		call push_temps_on_stack
		call set_gsa
		call pull_temps_from_stack
		ldw ra, 0(sp)
		addi sp, sp, 4
		addi a1, a1, 1
		blt a1, t0, set_seed0_in_gsa

	;game state 0 is initialized to seed 0
	stw zero, SEED(zero)

	;displaying the seed on the LEDs
	addi sp, sp, -4
	stw ra, 0(sp)
	call push_temps_on_stack
	call draw_gsa
	call pull_temps_from_stack
	ldw ra, 0(sp)
	addi sp, sp, 4

	;GSA ID is 0
	stw zero, GSA_ID(zero)
	
	;game is currently paused
	stw zero, PAUSE(zero)
	
	;game speed is 1
	addi t0, zero, MIN_SPEED
	stw t0, SPEED(zero)
	ret
;END:reset_game


font_data:
    .word 0xFC ; 0
    .word 0x60 ; 1
    .word 0xDA ; 2
    .word 0xF2 ; 3
    .word 0x66 ; 4
    .word 0xB6 ; 5
    .word 0xBE ; 6
    .word 0xE0 ; 7
    .word 0xFE ; 8
    .word 0xF6 ; 9
    .word 0xEE ; A
    .word 0x3E ; B
    .word 0x9C ; C
    .word 0x7A ; D
    .word 0x9E ; E
    .word 0x8E ; F

seed0:
    .word 0xC00
    .word 0xC00
    .word 0x000
    .word 0x060
    .word 0x0A0
    .word 0x0C6
    .word 0x006
    .word 0x000

seed1:
    .word 0x000
    .word 0x000
    .word 0x05C
    .word 0x040
    .word 0x240
    .word 0x200
    .word 0x20E
    .word 0x000

seed2:
    .word 0x000
    .word 0x010
    .word 0x020
    .word 0x038
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

seed3:
    .word 0x000
    .word 0x000
    .word 0x090
    .word 0x008
    .word 0x088
    .word 0x078
    .word 0x000
    .word 0x000

    ;; Predefined seeds
SEEDS:
    .word seed0
    .word seed1
    .word seed2
    .word seed3

mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000

MASKS:
    .word mask0
    .word mask1
    .word mask2
    .word mask3
    .word mask4
