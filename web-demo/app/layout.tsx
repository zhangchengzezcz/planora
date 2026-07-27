import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://zhangchengzezcz.github.io/planora/"),
  title: "Planora 交互式演示",
  description:
    "体验面向 IB 与 IGCSE 学生的 Planora 学习规划 App：任务、Deadline、今日计划、进度与搜索。",
  icons: {
    icon: "https://zhangchengzezcz.github.io/planora/icon.png",
  },
  openGraph: {
    title: "Planora 交互式演示",
    description: "让复杂的国际课程安排变得清晰。",
    type: "website",
    locale: "zh_CN",
    url: "https://zhangchengzezcz.github.io/planora/",
    images: [
      {
        url: "https://zhangchengzezcz.github.io/planora/og.png",
        width: 1200,
        height: 630,
        alt: "Planora 交互式 App 演示",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Planora 交互式演示",
    description: "让复杂的国际课程安排变得清晰。",
    images: ["https://zhangchengzezcz.github.io/planora/og.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-Hans">
      <body>{children}</body>
    </html>
  );
}
