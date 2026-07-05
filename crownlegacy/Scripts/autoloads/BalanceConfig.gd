extends Node

# ==================== СИСТЕМА ДОВЕРИЯ ====================
@export_category("Система доверия")
@export_range(-100, 100) var initial_trust: int = 0
@export_range(0, 10) var initial_will: int = 3
