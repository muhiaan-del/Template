# 🎓 EduAssist: Institutional AI-Powered LMS

EduAssist is a full-stack, multi-tenant Learning Management System (LMS) that integrates AI directly into the university curriculum. Unlike generic chatbots, EduAssist is curriculum-grounded, meaning it only answers student questions based on the lecturer's uploaded materials.

## ✨ Features

- **Multi-Tenant Architecture:** Strict hierarchy (Admin → Faculty → Course → Unit → Class → Student).
- **RAG-Powered AI Chat:** Uses pgvector and Groq to answer student questions with citations from course materials.
- **Scanned PDF OCR:** Automatically extracts text from standard PDFs, scanned PDFs, and images using Tesseract.js and `pdf-to-png-converter`.
- **AI Flashcards & Notes:** Students can generate study materials directly from the AI chat.
- **Live Audio Sessions:** Integrated with LiveKit for one-way audio broadcasts from lecturers to students.
- **Manual Quiz Builder:** Faculty can create and publish quizzes for students to take.

---

## 🛠️ Tech Stack

- **Framework:** Next.js 16 (App Router, Turbopack)
- **Database & Auth:** Supabase (PostgreSQL, pgvector, Row Level Security)
- **AI Engine:** Groq API (`llama-3.3-70b-versatile`)
- **Embeddings:** Jina AI (`jina-embeddings-v2-base-en`)
- **OCR:** Tesseract.js + `pdf-to-png-converter`
- **Live Audio:** LiveKit Cloud
- **Styling:** Tailwind CSS v4

---

## 🚀 Live Demo & One-Click Deploy

- **Live Demo:** [https://templatem-pied.vercel.app](https://templatem-pied.vercel.app)
- **Deploy your own instance:** Click the button below. 

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fmuhiaan-del%2Ftemplatem&env=NEXT_PUBLIC_SUPABASE_URL,NEXT_PUBLIC_SUPABASE_ANON_KEY,SUPABASE_SERVICE_ROLE_KEY,GROQ_API_KEY,JINA_API_KEY,LIVEKIT_API_KEY,LIVEKIT_API_SECRET,NEXT_PUBLIC_LIVEKIT_URL)

---

## 💻 Local Development Setup

Follow these steps to get your own instance of EduAssist running locally.

### 1. Prerequisites
You will need accounts for the following services (all have free tiers):
- [Supabase](https://supabase.com/) (Database & Auth)
- [Groq](https://console.groq.com/keys) (AI Chat)
- [Jina AI](https://jina.ai/) (Text Embeddings)
- [LiveKit Cloud](https://livekit.io/) (Live Audio)

### 2. Clone the Repository
```bash
git clone https://github.com/muhiaan-del/templatem.git
cd templatem
npm install