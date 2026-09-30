import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        accent: "#E57697",
        "accent-dark": "#d4607f",
        base: {
          900: "#0e0e12",
          850: "#14141a",
        },
      },
      borderRadius: {
        "4xl": "2rem",
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(229, 118, 151, 0.2), 0 18px 40px rgba(229, 118, 151, 0.2)",
      },
      backgroundImage: {
        "hero-noise": "radial-gradient(circle at 18% 12%, rgba(229, 118, 151, 0.22), transparent 38%), radial-gradient(circle at 80% 10%, rgba(130, 96, 255, 0.14), transparent 34%), radial-gradient(circle at 50% 100%, rgba(229, 118, 151, 0.08), transparent 45%)",
      },
      keyframes: {
        "animate-up": {
          "0%": { opacity: "0", transform: "translateY(16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "animate-down": {
          "0%": { opacity: "0", transform: "translateY(-16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        "animate-up": "animate-up 0.6s cubic-bezier(0.2, 0.65, 0.3, 1) both",
        "animate-down": "animate-down 0.6s cubic-bezier(0.2, 0.65, 0.3, 1) both",
      },
    },
  },
  plugins: [],
};

export default config;
