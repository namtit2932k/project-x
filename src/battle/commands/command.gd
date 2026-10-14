extends RefCounted
class_name BattleCommand
## Every confirmed player/AI action is a command applied to BattleState. A snapshot is pushed
## by the director before execution, so undo is rewind-based, not command-undo.