# MediaCrawlerPro 自动爬取脚本说明文档

## 概述

`crawler.sh` 是一个用于在 Ubuntu 系统上一键启动 MediaCrawlerPro 全部服务的自动化脚本，支持自动管理 3 个项目的启动、停止、日志输出。

---

## 支持的功能

| 功能 | 说明 |
|-----|------|
| 一键启动 | 自动启动 SignSrv、CookieBridge、爬虫循环 |
| 一键停止 | 自动停止所有相关进程 |
| 状态查看 | 查看各服务运行状态 |
| 日志查看 | 查看实时日志 |
| 断点续爬 | 自动继承项目的断点续爬功能 |

---

## 文件结构

```
/path/to/MediaCrawlerPro/
├── crawler.sh                    # 主入口脚本（运行这个）
├── crawler_loop.sh             # 自动生成的爬虫循环脚本
├── pid.txt                     # 进程ID文件（合并为1个）
├── logs/                        # 日志目录（自动创建）
│   ├── signsrv.log             # 签名服务日志
│   ├── cookiebridge.log         # Cookie服务日志
│   ├── crawler循环.log         # 主循环日志
│   ├── xhs_YYYYMMDD.log      # 小红书爬取日志
│   ├── dy_YYYYMMDD.log       # 抖音爬取日志
│   └── bili_YYYYMMDD.log     # B站爬取日志
```

---

## 使用方法

### 1. 启动所有服务

```bash
./crawler.sh start
```

启动流程：
```
1. 检查 uv 是否已安装（如未安装，自动安装）
2. 检查 3 个项目目录是否存在
3. 停止已有进程（防止重复启动）
4. 清空各平台日志文件
5. 启动 SignSrv（签名服务）
6. 启动 CookieBridge（Cookie同步服务）
7. 启动爬虫循环（xhs → dy → bili → 等待 → 循环）
```

### 2. 停止所有服务

```bash
./crawler.sh stop
```

会停止：
- pid.txt 中记录的所有进程
- 所有相关的 uv run app.py 进程

### 3. 查看服务状态

```bash
./crawler.sh status
```

输出示例：
```
==========================================
  MediaCrawlerPro 服务状态
==========================================
● SignSrv (PID: 12345)
● CookieBridge (PID: 12346)
● Crawler循环 (PID: 12347)
==========================================
状态: 全部运行中
==========================================
```

### 4. 查看日志列表

```bash
./crawler.sh logs
```

### 5. 实时查看日志

```bash
./crawler.sh tail
```

### 6. 重启所有服务

```bash
./crawler.sh restart
```

---

## 核心配置

打开 `crawler.sh`，找到 `核心配置` 区域，可以修改以下参数：

```bash
# ---------- 核心配置（可自定义）----------
KEYWORDS="deepseek,chatgpt"       # 爬取关键词
MAX_COUNT=10                     # 爬取数量，默认10条
ENABLE_COMMENTS=false            # 是否爬取评论，false=不爬，true=爬
MAX_COMMENTS_PER_NOTE=50       # 每个帖子最大评论数，0=不限制
DY_PUBLISH_TIME=1             # 抖音时间筛选：0=不限，1=一天内，7=一周内
INTERVAL=7200                     # 循环间隔（秒），2小时=7200
PLATFORMS=("xhs" "dy" "bili")    # 爬取平台顺序
CRAWLER_TYPE="search"             # 爬取类型
```

### 配置说明

| 参数 | 默认值 | 说明 |
|-----|-------|------|
| KEYWORDS | deepseek,chatgpt | 爬取关键词，用逗号分隔 |
| MAX_COUNT | 10 | 爬取数量 |
| ENABLE_COMMENTS | false | 是否爬取评论，true=爬（较慢）|
| MAX_COMMENTS_PER_NOTE | 50 | 每个帖子最大评论数，0=不限制 |
| DY_PUBLISH_TIME | 1 | 抖音时间筛选：0=不限，1=一天内，7=一周内，180=半年内 |
| INTERVAL | 7200 | 整体循环间隔（秒），默认2小时 |
| PLATFORMS | xhs,dy,bili | 爬取平台顺序 |
| CRAWLER_TYPE | search | 爬取类型 |

### 修改关键字步骤

```bash
# 1. 编辑 crawler.sh
vim crawler.sh

# 2. 找到 KEYWORDS 行，修改为你要的关键词
KEYWORDS="AI,科技,热点"

# 3. 保存并重启
./crawler.sh restart
```

---

## 爬虫循环流程

```
┌────────────────────────────────────────┐
│                  主循环开始               
└─────────────────── ────────────────────┘
                    │
                    ▼
            ┌───────────────┐
                 爬取 xhs      
                (小红书)      
            └───────────────┘
                    │
                    ▼ 失败跳过，成功继续
            ┌───────────────┐
                 等待 10s      
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
                 爬取 dy      
                 (抖音)        
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
                 等待 10s      
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
                 爬取 bili     
                 (B站)        
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
                等待 INTERVAL 
                (默认2小时)    
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
                 循环开始      
            └───────────────┘
```

---

## 平台间容错机制

- **某个平台失败** → 跳过继续爬取下一个平台
- **其他平台不受影响** → 独立的错误处理
- **单日日志** → 每天生成新的日志文件

---

## 服务端口说明

| 服务 | 端口 | 用途 |
|-----|------|------|
| SignSrv | 8090 | 请求签名验证 |
| CookieBridge | 8274 | Cookie 自动同步 |
| Crawler | - | 无端口，通过上述服务获取 Cookie |

---

## 兼容性

### 最低要求

- **系统**: Ubuntu 16.04+
- **依赖**: uv（脚本自动安装）
- **网络**: 能访问外网（用于安装 uv）

### 自动检测

脚本会自动检测：
1. uv 是否已安装
2. 3 个项目目录是否存在
3. PID 文件对应的进程是否存活

### 换电脑部署

将整个 `MediaCrawlerPro/` 目录复制到新电脑即可，无需修改任何配置。

---

## 常见问题

### 1. 启动失败：uv 未安装

**解决**：脚本会自动安装，如手动安装：
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. 启动失败：项目目录不存在

**确认目录结构**：
```
MediaCrawlerPro/
├── MediaCrawlerPro-SignSrv/
├── MediaCrawlerPro-CookieBridge/
├── MediaCrawlerPro-Python/
└── crawler.sh
```

### 3. 爬取失败：无账号

**原因**：CookieBridge 中没有登录的账号

**解决**：
1. 在浏览器安装 CookieBridge Extension
2. 登录对应平台账号
3. 重启爬虫：`./crawler.sh restart`

### 4. 查看具体错误

```bash
# 查看主循环日志
./crawler.sh logs

# 实时查看
./crawler.sh tail

# 查看特定平台日志
cat logs/xhs_20260409.log
```

---

## 扩展：修改 B 站爬取类型

B 站默认使用 `search`（关键词搜索）。

如需修改爬取类型，编辑 `crawler.sh`：

```bash
# 找到这行，修改为 detail 或其他
CRAWLER_TYPE="search"
```

支持的类型（参考各平台）：
- `search` - 关键词搜索
- `detail` - 帖子详情
- `creator` - 创作者主页

---

## 扩展：单独启动某个服务

### 只启动 SignSrv

```bash
cd MediaCrawlerPro-SignSrv
uv run app.py
```

### 只启动 CookieBridge

```bash
cd MediaCrawlerPro-CookieBridge/server
uv run app.py
```

### 只启动爬虫循环

```bash
cd MediaCrawlerPro-Python
# 手动运行
uv run main.py --platform xhs --type search
```

---

## 调试日志级别

当前日志级别为 INFO，如需更详细日志，可修改各项目的日志配置。

---

## 注意事项

1. **首次运行前配置账号** - 确保 CookieBridge 有对应平台的登录账号
2. **合理设置间隔** - 避免被平台封 IP
3. **定期检查日志** - 查看是否有错误
4. **磁盘空间** - 日志会不断累积，建议定期清理

---

## 相关项目文档

- [MediaCrawlerPro 主项目](https://github.com/MediaCrawlerPro/MediaCrawlerPro-Python)
- [SignSrv 签名服务](https://github.com/MediaCrawlerPro/MediaCrawlerPro-SignSrv)
- [CookieBridge](https://github.com/MediaCrawlerPro/MediaCrawlerPro-CookieBridge)
