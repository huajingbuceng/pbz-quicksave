# PBZ QuickSave

《影之刃零》(Phantom Blade Zero) 的 UE4SS 模组：**随时存档 + 位置记忆**。

给这个游戏加一个「临时检查点」——打 Boss 前按一下，翻车了能回去。

> 现状：**存档和传送可用，游戏内读档不可用。** 原因见 [技术笔记](docs/存档系统逆向笔记.md)，不是没做完，是这条路在当前工具链下走不通。

---

## 它能做什么

| 按键 | 功能 | 状态 |
|---|---|---|
| `F8` | 让游戏存一次档 + 记录当前坐标 | ✅ 实测可用 |
| `F9` | 传送回记录的坐标（不读档） | ✅ 实测可用 |
| `F11` | 打印当前坐标与记录坐标 | ✅ |

存档调用的是游戏自己的 `PBZSaveLoadSubsystem::TrySave`，**写进的是「继续」那个槽**。所以完整的回档流程是：

```
打 Boss 前        →  F8
翻车              →  退出到主菜单 → 点「继续」→ 回到 F8 那一刻
想回到原地        →  F9
```

`F9` 只是把人搬回去，不改任何进度。真正的「回到那一刻」由「继续」完成。

## 它做不到什么

**游戏内热键读档。** 试过 10 种调用方式都失败，包括：

- `PBZSaveLoadSubsystem:LoadGame` —— 进了函数但立刻返回
- `PBZCheatManager:GM_LoadGame` —— 传任何槽名都是空操作
- `PBZDestinationLoadingSubsystem:ArmForSaveSlot` —— 5 个 Trigger 值全部无效
- 暂停后读档、死亡重生、重放游戏自己的调用参数 —— 均无效

根因是 `LoadGame` 的第二个参数是 **Out 参数**（`LoadGameResultParam` 结构体），UE4SS 的 Lua 层只能传空表，游戏拿到的是全零结构体，于是在入口就返回了。

详见 [技术笔记](docs/存档系统逆向笔记.md)。

---

## 安装

### 前置：UE4SS

需要 [UE4SS for Phantom Blade Zero](https://github.com/KintaroModding/ue4ss)（KintaroModding 维护的 PBZ 专用分支）。
到 Releases 页下载 `phantombladezero_ue4ss_*.zip`，解压到：

```
...\PBZ\platform\steam\
```

### 安装模组

把本仓库的 `mod/` 目录复制到：

```
...\PBZ\platform\steam\ue4ss\Mods\PBZQuickSave\
```

最终结构：

```
ue4ss\Mods\PBZQuickSave\enabled.txt
ue4ss\Mods\PBZQuickSave\Scripts\main.lua
```

有 `enabled.txt` 就会自动加载，不需要改 `mods.txt`。

### 一键安装（可选）

```powershell
# 在游戏根目录的上两级执行
.\installer\install.bat
```

脚本会自动找游戏目录、备份已有文件、复制、校验。

### 卸载

删掉 `ue4ss\Mods\PBZQuickSave` 整个文件夹。不修改任何游戏文件。

---

## 坐标存在哪

```
...\PBZ\ProjectPBZ\Binaries\Win64\pos.txt
```

游戏进程的工作目录就在 `Binaries\Win64`，所以放在这里能跨重启读到。

格式：`X,Y,Z,Yaw,地图名`

---

## 已知问题

1. **`F8` 写的是主存档槽（`AutoSave0`）**
   `F8` 之后的所有进度，都会被下一次「继续」抹掉——这是「检查点」的固有含义，不是 bug。

2. **运行中强制存档可能留下边缘状态**
   读档后偶见 `SendGameplayEventToActor: Invalid ability system component` 这类报错（例如梯子触发失败）。重新进出该区域或重启游戏通常可恢复。

3. **只有一个记录点**
   再按一次 `F8` 就覆盖上一次。

---

## 环境

- 游戏：Phantom Blade Zero（UE 5.7，Steam 版）
- 模组框架：UE4SS `v3.0.1-1195`（KintaroModding PBZ 分支）
- 实测平台：Windows 11

## 免责声明

非官方模组，与 S-GAME 无关。仅用于单机。使用前请自行备份存档。
改动游戏内存状态存在风险，出问题请卸载本模组。

## License

MIT，见 [LICENSE](LICENSE)。
