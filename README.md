# 🎨 Vehloom

> **Where Creativity Blooms.**

Vehloom is an AI-powered creative community built for people who want to **create, discover, and share AI-generated artwork**.

It combines AI image generation with a social experience, allowing creators to turn ideas into artwork, publish their creations, discover other artists, and build a creative identity around their work.

---

## ✨ What is Vehloom?

AI image generation makes it easier than ever to create artwork — but creating an image is only one part of the experience.

Vehloom is designed to bring **creation + discovery + community** together in one platform.

Users can generate artwork with AI, share it with the community, explore creations from other artists, follow creators they enjoy, and build their own collection of favorite work.

```text
                    ┌─────────────────┐
                    │     Vehloom     │
                    └────────┬────────┘
                             │
             ┌───────────────┼───────────────┐
             │               │               │
             ▼               ▼               ▼
        🎨 CREATE       🔎 DISCOVER      👥 CONNECT
             │               │               │
        AI Artwork       Explore Feed    Follow Creators
        AI Generation    Trending Art    Like & Comment
             │               │               │
             └───────────────┼───────────────┘
                             ▼
                    🌱 CREATIVE COMMUNITY
```

---

# 🚀 Core Features

## 🤖 AI Image Generation

Vehloom allows users to turn creative ideas into AI-generated artwork.

Users can:

* Enter creative prompts
* Generate AI artwork
* Preview generated results
* Publish creations to the community
* Add titles, descriptions, and tags
* Build a personal collection of generated artwork

AI image generation is powered through **Flux-based image generation**.

---

## 🖼️ Creative Social Feed

The home feed provides a visual-first experience for discovering artwork from the community.

Users can:

* Browse artwork
* Like creations
* Comment on posts
* Follow creators
* Save artwork
* Open creator profiles
* Discover new artists

The feed is designed around visual discovery rather than traditional text-heavy social media.

---

## 🔎 Explore & Discover

Vehloom provides multiple ways to discover artwork.

### Categories

Artwork can be organized around creative styles such as:

* Portrait
* Landscape
* 3D Art
* Anime
* Abstract
* Digital Art

### Explore

The Explore experience uses a visual masonry-style layout to make browsing large collections of artwork more engaging.

---

## 👤 Creator Profiles

Every creator can build a visual identity on Vehloom.

Profiles can include:

* Profile information
* Published artwork
* Followers
* Following
* Favorite creations
* Creator activity

Users can follow artists whose work they want to see more frequently.

---

## ❤️ Social Interactions

Vehloom includes core social functionality:

* Likes
* Comments
* Follows
* Favorites
* Notifications
* Stories
* Search

These features create an environment where creators can share work and interact with other members of the community.

---

# 🧭 User Experience

The application follows a simple creative journey:

```text
Open Vehloom
     ↓
Authentication
     ↓
Onboarding
     ↓
Choose Creative Interests
     ↓
Explore Artwork
     ↓
Generate / Discover
     ↓
Publish Artwork
     ↓
Build Creator Profile
     ↓
Connect With Community
```

During onboarding, users can select interests such as:

```text
Portrait
Landscape
3D Art
Anime
Abstract
Digital Art
```

These preferences can be used to improve the discovery experience.

---

# 🏗️ Architecture

Vehloom follows a modular application architecture designed to separate UI, features, authentication, data access, and backend services.

```text
┌─────────────────────────────────────┐
│            Vehloom App              │
├─────────────────────────────────────┤
│                                     │
│ Authentication                      │
│ ├── Email Login                     │
│ ├── Google Authentication           │
│ └── Session Management               │
│                                     │
├─────────────────────────────────────┤
│                                     │
│ Social Experience                   │
│ ├── Feed                            │
│ ├── Explore                         │
│ ├── Profiles                        │
│ ├── Likes                           │
│ ├── Comments                        │
│ ├── Follows                         │
│ └── Favorites                       │
│                                     │
├─────────────────────────────────────┤
│                                     │
│ AI Creation                         │
│ ├── Prompt Input                    │
│ ├── Image Generation                │
│ └── Generated Artwork               │
│                                     │
├─────────────────────────────────────┤
│                                     │
│ Communication                       │
│ ├── Notifications                   │
│ ├── Stories                         │
│ └── Chat                             │
│                                     │
└──────────────────┬──────────────────┘
                   │
                   ▼
          ┌──────────────────┐
          │    Supabase      │
          ├──────────────────┤
          │ Authentication   │
          │ PostgreSQL       │
          │ Storage          │
          │ Row Level        │
          │ Security         │
          └──────────────────┘
                   │
                   ▼
          ┌──────────────────┐
          │ AI Generation    │
          │      Flux        │
          └──────────────────┘
```

---

# 🛠️ Tech Stack

| Technology             | Purpose                           |
| ---------------------- | --------------------------------- |
| **Flutter**            | Cross-platform mobile application |
| **Dart**               | Application development           |
| **Supabase**           | Backend infrastructure            |
| **PostgreSQL**         | Relational database               |
| **Supabase Auth**      | Authentication & sessions         |
| **Supabase Storage**   | Artwork/media storage             |
| **Row Level Security** | Database access control           |
| **Flux**               | AI image generation               |
| **Git / GitHub**       | Version control                   |

---

# 📱 Application Modules

```text
Vehloom
│
├── Authentication
│   ├── Login
│   ├── Registration
│   ├── Google Sign-In
│   └── Session Management
│
├── Onboarding
│   └── Creative Preferences
│
├── Home
│   ├── Feed
│   ├── Stories
│   └── Trending Artwork
│
├── Explore
│   ├── Categories
│   ├── Search
│   └── Visual Discovery
│
├── AI Creation
│   ├── Prompt
│   ├── Generation
│   └── Publish
│
├── Social
│   ├── Likes
│   ├── Comments
│   ├── Follows
│   └── Favorites
│
├── Profile
│   ├── Creator Profile
│   ├── Artwork
│   └── Followers / Following
│
├── Notifications
│
└── Chat
```

---

# 🔐 Backend & Data

Vehloom uses **Supabase** as its backend platform.

The backend handles:

* User authentication
* User profiles
* Artwork metadata
* Likes
* Comments
* Followers / following
* Favorites
* Notifications
* Chat
* Artwork storage

Database access is protected using **Row Level Security (RLS)** policies to control which users can read or modify specific records.

---

# 💬 Real-Time Chat

Vehloom includes a community messaging system built around Supabase.

The messaging architecture uses concepts such as:

```text
Chat Room
    │
    ├── Participants
    │
    └── Messages
          ├── Sender
          ├── Content
          ├── Timestamp
          └── Read Status
```

This enables creators to communicate without requiring a separate messaging platform.

---

# 🎨 Design Philosophy

Vehloom is designed around a simple principle:

> **AI should make creativity more accessible, while community makes it meaningful.**

The interface focuses on:

* Visual-first content
* Minimal friction
* Creative discovery
* Creator identity
* Community interaction
* Simple AI generation

The current visual identity uses a dark, warm aesthetic with cream and coral accents.

---

# 📸 Screenshots

Add screenshots of the application here:

```text
screenshots/
├── onboarding.png
├── home.png
├── explore.png
├── create.png
├── artwork.png
├── profile.png
└── chat.png
```

Example:

| Home           | Explore        | AI Creation    |
| -------------- | -------------- | -------------- |
| Add Screenshot | Add Screenshot | Add Screenshot |

| Artwork        | Profile        | Chat           |
| -------------- | -------------- | -------------- |
| Add Screenshot | Add Screenshot | Add Screenshot |

---

# ⚙️ Getting Started

## Prerequisites

Make sure you have:

* Flutter SDK
* Dart SDK
* Android Studio / Android SDK
* A Supabase project
* Git

Check your Flutter installation:

```bash
flutter doctor
```

---

## Clone the Repository

```bash
git clone https://github.com/ahmad124/vehloom.git
cd vehloom
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Configure Environment

Create the required environment configuration for:

```text
Supabase URL
Supabase Anon Key
AI Image Generation API
```

Do **not** commit private API keys or service-role credentials to GitHub.

---

## Run the Application

Connect an Android device or start an emulator:

```bash
flutter run
```

---

# 🌱 Product Roadmap

Vehloom is being developed toward a broader AI-powered creative ecosystem.

### 🔄 Discovery

* Personalized recommendations
* Trending artwork
* Collections
* Advanced categories
* Feed personalization

### 🎨 Creation

* More AI generation models
* Generation history
* Multiple image variations
* Advanced generation controls
* Image-to-image generation

### 👥 Community

* Creator badges
* Artist collections
* Community challenges
* Enhanced creator profiles
* Collaboration features

### 📊 Creator Tools

* Creator analytics
* Artwork performance
* Audience insights
* Engagement analytics

---

# 📈 Vision

Vehloom aims to become a place where people don't just **generate AI images**, but actually **build a creative identity around them**.

The long-term vision is to connect:

```text
AI Creation
     +
Creative Discovery
     +
Social Community
     +
Creator Identity
     ↓
  VE HLOOM
```

---

# 👨‍💻 Founder & Developer

**Malik Ahmad Rasheed**

Solo Founder & Developer

Vehloom is independently designed and developed from product concept through application development, backend architecture, AI integration, and deployment.

**Product:** Vehloom
**Website:** https://vehloom.vercel.app

---

# 📄 License

This project is currently proprietary.

All rights reserved unless otherwise specified.

---

<p align="center">
  <strong>Vehloom — Where Creativity Blooms.</strong>
</p>
```

### One thing I'd strongly recommend

Don't make the GitHub README just a giant wall of technical information. **Put 4–6 actual app screenshots near the top** after the intro. For a visual product like Vehloom, someone landing on the repository should immediately see:

**Logo → tagline → screenshots → what it does → features → architecture → tech stack.**

That will make the repository look much more like a **real startup/product repo** and less like a university assignment.
