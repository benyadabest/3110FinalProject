open Pieces

type square = Pieces.piece option
type board = square array array

(* ANSI color codes for visualization *)
let red = "\027[31m"
let blue = "\027[34m"
let reset = "\027[0m"

(* Helper function to check valid board positions *)
let is_valid_position (row, col) =
  row >= 0 && row < 8 && col >= 0 && col < 8

(* Retrieve a piece from the board *)
let get_piece_at (board : board) (row, col) : square =
  if is_valid_position (row, col) then
    board.(row).(col)
  else
    None

(* Helper function to check if a square is empty *)
let is_empty_square (board : board) (row, col) =
  match get_piece_at board (row, col) with
  | None -> true
  | Some _ -> false

(* Simple kingside castling check *)
let can_castle_kingside (board : board) (color : string) : bool =
  let row = if color = "White" then 7 else 0 in
  (* Check king and rook are in initial positions *)
  match get_piece_at board (row, 4), get_piece_at board (row, 7) with
  | Some king, Some rook ->
      get_piece_type king = "King" && get_piece_type rook = "Rook" &&
      get_color king = color && get_color rook = color &&
      (* Check path between king and rook is clear *)
      is_empty_square board (row, 5) && is_empty_square board (row, 6)
  | _ -> false

(* Perform kingside castling *)
let do_castle_kingside (board : board) (color : string) : board =
  let row = if color = "White" then 7 else 0 in
  if not (can_castle_kingside board color) then
    failwith "Invalid castling move"
  else
    let new_board = Array.map Array.copy board in
    (* Move king *)
    new_board.(row).(6) <- new_board.(row).(4);
    new_board.(row).(4) <- None;
    (* Move rook *)
    new_board.(row).(5) <- new_board.(row).(7);
    new_board.(row).(7) <- None;
    new_board

(* Updated pawn movement logic *)
let valid_pawn_moves (board : board) (piece : piece) (start_row, start_col) : (int * int) list =
  let color = get_color piece in
  let direction = if color = "White" then -1 else 1 in
  let start_rank = if color = "White" then 6 else 1 in
  let moves = ref [] in
  
  (* Forward move - only if square is empty *)
  let forward = (start_row + direction, start_col) in
  if is_valid_position forward && is_empty_square board forward then begin
    moves := forward :: !moves;
    
    (* Initial two-square move - only from starting rank and if path is clear *)
    if start_row = start_rank then
      let double_forward = (start_row + (2 * direction), start_col) in
      if is_valid_position double_forward && is_empty_square board double_forward then
        moves := double_forward :: !moves
  end;
  
  (* Diagonal captures - only if enemy piece is present *)
  List.iter (fun dc ->
    let capture_pos = (start_row + direction, start_col + dc) in
    if is_valid_position capture_pos then
      match get_piece_at board capture_pos with
      | Some target when get_color target <> color ->
          moves := capture_pos :: !moves
      | _ -> ()
  ) [-1; 1];
  
  !moves

(* Updated sliding piece movement logic *)
let rec sliding_moves board piece (start_row, start_col) (delta_row, delta_col) acc =
  let next_row = start_row + delta_row in
  let next_col = start_col + delta_col in
  
  if not (is_valid_position (next_row, next_col)) then 
    acc
  else 
    match get_piece_at board (next_row, next_col) with
    | None -> 
        (* Square is empty, can continue sliding *)
        sliding_moves board piece (next_row, next_col) (delta_row, delta_col) 
          ((next_row, next_col) :: acc)
    | Some target_piece ->
        if get_color target_piece <> get_color piece then
          (* Can capture opponent's piece but can't move further *)
          (next_row, next_col) :: acc
        else
          (* Blocked by friendly piece *)
          acc

(* Valid moves for any piece *)
let rec valid_piece_move (board : board) (piece : piece) (start_row, start_col) : (int * int) list =
  match get_piece_type piece with
  | "Pawn" -> valid_pawn_moves board piece (start_row, start_col)
  | "Rook" ->
      List.concat [
        sliding_moves board piece (start_row, start_col) (1, 0) [];
        sliding_moves board piece (start_row, start_col) (-1, 0) [];
        sliding_moves board piece (start_row, start_col) (0, 1) [];
        sliding_moves board piece (start_row, start_col) (0, -1) []
      ]
  | "Bishop" ->
      List.concat [
        sliding_moves board piece (start_row, start_col) (1, 1) [];
        sliding_moves board piece (start_row, start_col) (-1, -1) [];
        sliding_moves board piece (start_row, start_col) (1, -1) [];
        sliding_moves board piece (start_row, start_col) (-1, 1) []
      ]
  | "Queen" ->
      List.concat [
        sliding_moves board piece (start_row, start_col) (1, 0) [];
        sliding_moves board piece (start_row, start_col) (-1, 0) [];
        sliding_moves board piece (start_row, start_col) (0, 1) [];
        sliding_moves board piece (start_row, start_col) (0, -1) [];
        sliding_moves board piece (start_row, start_col) (1, 1) [];
        sliding_moves board piece (start_row, start_col) (-1, -1) [];
        sliding_moves board piece (start_row, start_col) (1, -1) [];
        sliding_moves board piece (start_row, start_col) (-1, 1) []
      ]
  | "Knight" ->
    let offsets = [
      (2, 1); (2, -1); (-2, 1); (-2, -1);
      (1, 2); (1, -2); (-1, 2); (-1, -2)
    ] in
    List.map (fun (dr, dc) -> 
      (start_row + dr, start_col + dc)
    ) offsets |> List.filter (fun (r, c) ->
      is_valid_position (r, c) &&
      match get_piece_at board (r, c) with
      | None -> true
      | Some target -> get_color target <> get_color piece
    )
  | "King" ->
      let standard_moves = List.filter (fun (dr, dc) ->
        let new_row = start_row + dr in
        let new_col = start_col + dc in
        is_valid_position (new_row, new_col) &&
        match get_piece_at board (new_row, new_col) with
        | None -> true
        | Some target -> get_color target <> get_color piece
      ) [(1, 0); (-1, 0); (0, 1); (0, -1);
         (1, 1); (1, -1); (-1, 1); (-1, -1)] in
      
      (* Add castling move if possible *)
      if (start_row = 7 && start_col = 4 && get_color piece = "White" && 
          can_castle_kingside board "White") ||
         (start_row = 0 && start_col = 4 && get_color piece = "Black" && 
          can_castle_kingside board "Black") then
        (start_row, 6) :: standard_moves
      else
        standard_moves
  | _ -> []

(* Check if a move is valid *)
let is_valid_move (board : board) (start_pos : int * int) (end_pos : int * int) : bool =
  let start_row, start_col = start_pos in
  let end_row, end_col = end_pos in
  match get_piece_at board start_pos with
  | None -> false
  | Some piece ->
      (* Check if it's a castling move *)
      if get_piece_type piece = "King" && 
         ((start_row = 7 && start_col = 4 && end_row = 7 && end_col = 6) ||
          (start_row = 0 && start_col = 4 && end_row = 0 && end_col = 6)) then
        can_castle_kingside board (get_color piece)
      else
        (* Normal move - check if it's in the list of valid moves *)
        List.mem end_pos (valid_piece_move board piece (start_row, start_col))

(* Auto-promotion of pawns to a queen *)
let promote_pawn (board : board) (row : int) (col : int) =
  match get_piece_at board (row, col) with
  | Some piece when get_piece_type piece = "Pawn" ->
      let color = get_color piece in
      if (color = "White" && row = 0) || (color = "Black" && row = 7) then
        board.(row).(col) <- Some (create_piece "Queen" color)
  | _ -> ()

(* Move a piece on the board *)
let move_piece (board : board) (start_pos : int * int) (end_pos : int * int) : board =
  if not (is_valid_move board start_pos end_pos) then
    failwith "Invalid move"
  else
    let start_row, start_col = start_pos in
    let end_row, end_col = end_pos in
    match get_piece_at board start_pos with
    | None -> failwith "No piece at start position" (* This should never happen due to is_valid_move check *)
    | Some piece ->
        if get_piece_type piece = "King" && 
           ((start_row = 7 && start_col = 4 && end_row = 7 && end_col = 6) ||
            (start_row = 0 && start_col = 4 && end_row = 0 && end_col = 6)) then
          (* Castling move *)
          do_castle_kingside board (get_color piece)
        else
          (* Normal move *)
          let new_board = Array.map Array.copy board in
          new_board.(end_row).(end_col) <- new_board.(start_row).(start_col);
          new_board.(start_row).(start_col) <- None;
          promote_pawn new_board end_row end_col;
          new_board

let rec find_king (board : board) (color : string) : (int * int) =
  let rec search row col =
    if row >= 8 then failwith "King not found"
    else if col >= 8 then search (row + 1) 0
    else match get_piece_at board (row, col) with
      | Some piece when get_piece_type piece = "King" && get_color piece = color -> (row, col)
      | _ -> search row (col + 1)
  in
  search 0 0

(* Check if the king of a given color is in check *)
let is_check (board : board) (color : string) : bool =
  let king_pos = find_king board color in
  let opposite_color = if color = "White" then "Black" else "White" in
  List.exists (fun (row, col) ->
    match get_piece_at board (row, col) with
    | Some piece when get_color piece = opposite_color ->
        List.mem king_pos (valid_piece_move board piece (row, col))
    | _ -> false
  ) (List.init 64 (fun n -> (n / 8, n mod 8)))

(* Check if the king of a given color is in checkmate *)
let is_checkmate (board : board) (color : string) : bool =
  if not (is_check board color) then false
  else
    not (List.exists (fun (start_row, start_col) ->
      match get_piece_at board (start_row, start_col) with
      | Some piece when get_color piece = color ->
          List.exists (fun (end_row, end_col) ->
            try
              let new_board = move_piece board (start_row, start_col) (end_row, end_col) in
              not (is_check new_board color)
            with _ -> false
          ) (valid_piece_move board piece (start_row, start_col))
      | _ -> false
    ) (List.init 64 (fun n -> (n / 8, n mod 8))))

(* Convert algebraic notation to array indices *)
let algebraic_to_indices notation =
  if String.length notation <> 2 then
    failwith "Invalid notation format";
  let col = Char.code (Char.lowercase_ascii notation.[0]) - Char.code 'a' in
  let row = 8 - (int_of_char notation.[1] - int_of_char '0') in
  if not (is_valid_position (row, col)) then
    failwith "Invalid position";
  (row, col)

(* Convert array indices to algebraic notation *)
let indices_to_algebraic (row, col) =
  let col_char = char_of_int (col + Char.code 'a') in
  let row_char = char_of_int (8 - row + Char.code '0') in
  String.make 1 col_char ^ String.make 1 row_char

(* Move a piece using algebraic notation *)
let move_piece_algebraic (board : board) start_pos end_pos : board =
  let start_indices = algebraic_to_indices start_pos in
  let end_indices = algebraic_to_indices end_pos in
  move_piece board start_indices end_indices

(* Initialize the chessboard with pieces in their starting positions *)
let init_board () : board =
  let board = Array.make_matrix 8 8 None in
  let place_piece row col piece_type color =
    board.(row).(col) <- Some (create_piece piece_type color)
  in

  (* Place main pieces for both sides *)
  List.iter (fun (row, color) ->
    place_piece row 0 "Rook" color;
    place_piece row 1 "Knight" color;
    place_piece row 2 "Bishop" color;
    place_piece row 3 "Queen" color;
    place_piece row 4 "King" color;
    place_piece row 5 "Bishop" color;
    place_piece row 6 "Knight" color;
    place_piece row 7 "Rook" color
  ) [(0, "Black"); (7, "White")];

  (* Place pawns *)
  for col = 0 to 7 do
    place_piece 1 col "Pawn" "Black";
    place_piece 6 col "Pawn" "White";
  done;
  board

(* Check if the given color is in stalemate *)
let is_stalemate (board : board) (color : string) : bool =
  (* First verify we're not in check *)
  if is_check board color then false
  else
    (* Check if any piece has a legal move *)
    not (List.exists (fun (start_row, start_col) ->
      match get_piece_at board (start_row, start_col) with
      | Some piece when get_color piece = color ->
          List.exists (fun (end_row, end_col) ->
            try
              let new_board = move_piece board (start_row, start_col) (end_row, end_col) in
              not (is_check new_board color)
            with _ -> false
          ) (valid_piece_move board piece (start_row, start_col))
      | _ -> false
    ) (List.init 64 (fun n -> (n / 8, n mod 8))))

(* Print the chessboard *)
let print_board (board : board) : unit =
  print_endline "  +-----------------------+";
  for row = 0 to 7 do
    Printf.printf " %d | " (8 - row);
    for col = 0 to 7 do
      match board.(row).(col) with
      | None -> print_string "- "
      | Some piece ->
          let color = match get_color piece with
            | "White" -> red
            | "Black" -> blue
            | _ -> reset
          in
          let piece_str = match get_piece_type piece with
            | "King" -> "K"
            | "Queen" -> "Q"
            | "Rook" -> "R"
            | "Bishop" -> "B"
            | "Knight" -> "N"
            | "Pawn" -> "P"
            | _ -> "?"
          in
          Printf.printf "%s%s%s " color piece_str reset
    done;
    print_endline "|";
  done;
  print_endline "  +-----------------------+";
  print_endline "  a b c d e f g h"