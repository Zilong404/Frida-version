# Frida-version
 Frida 多版本管理与一键部署


📘 Frida 多版本管理与一键部署

功能简介

本方案提供 PC + 手机端闭环管理，实现一键切换和部署对应版本的 Frida Tools（PC 端）和 frida-server（手机端）。  

- PC 端（Windows）：usefrida.bat  
- 手机端（Android）：frida_auto_match.sh  

支持多版本共存、自动检测、缓存复用，解决了手动切换繁琐、重复 push 的问题。

---

🚀 快速开始

1. 前置依赖

PC 端（Windows）

- 安装 Python
- 安装 virtualenvwrapper-win  
      pip install virtualenvwrapper-win

手机端（Android）

- 手机已 root 或可通过 adb root 使用  
- 手机已安装 adb 并可连接 

---

2. PC 端脚本用法 (usefrida.bat)

📌 指定版本（会进入 frida-x.y.z 环境）

    usefrida.bat -Version 17.1.5

📌 指定已有环境

    usefrida.bat -Env frida17

📌 自动检测当前环境版本

    usefrida.bat

📌 自动杀旧的 frida-server

    usefrida.bat -Version 17.1.5 --kill

📌 查看帮助

    usefrida.bat -h

---

3. 手机端脚本用法 (frida_auto_match.sh)

📌 手动指定版本

    sh frida_auto_match.sh 17.1.5

📌 自动匹配（从 PC 端传入）

    sh frida_auto_match.sh

📌 杀旧进程再启动

    sh frida_auto_match.sh 17.1.5 --kill

📌 查看帮助

    sh frida_auto_match.sh -h

---

🧩 工作流程

1. PC 端  
   - 运行 usefrida.bat  
   - 自动进入正确虚拟环境并确定 frida-tools 版本  
2. PC → 手机  
   - 通过 adb shell 调用 frida_auto_match.sh，传递版本号  
3. 手机端  
   - 检查 /data/local/tmp/frida-server-<version> 是否已存在  
   - 如果不存在 → 自动 push 新的二进制文件  
   - 如果存在 → 直接启动，避免重复上传  

---

🎯 优点

- 多版本共存：可以在多个虚拟环境之间随意切换  
- 自动匹配：PC 端与手机端版本保持一致  
- 缓存复用：frida-server 已存在则直接复用，避免重复传输  
- 一键启动：从 PC 脚本到手机服务全程自动化  

---

📝 示例场景

    :: 场景 1：测试旧版本
    usefrida.bat -Version 16.1.0
    
    :: 场景 2：切换新版本并杀掉旧 frida-server
    usefrida.bat -Version 17.1.5 --kill
    
    :: 场景 3：使用已有 frida17 环境（非标准命名）
    usefrida.bat -Env frida17
    
    :: 场景 4：直接检测当前环境里的版本
    usefrida.bat

---

📌 目录结构建议

    project_root/
    │
    ├─ usefrida.bat              # Windows 一键脚本
    ├─ frida_auto_match.sh       # Android 一键脚本
    ├─ README.md                 # 使用文档（本文件）
    └─ ...

---


