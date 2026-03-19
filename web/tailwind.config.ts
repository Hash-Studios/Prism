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
        base: {
          950: "#070709",
          900: "#0e0e12",
          850: "#14141a",
          800: "#1a1a22",
          700: "#262633",
          600: "#343445",
        },
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(229, 118, 151, 0.2), 0 18px 40px rgba(229, 118, 151, 0.2)",
      },
      backgroundImage: {
        "hero-noise": "radial-gradient(circle at 18% 12%, rgba(229, 118, 151, 0.22), transparent 38%), radial-gradient(circle at 80% 10%, rgba(130, 96, 255, 0.14), transparent 34%), radial-gradient(circle at 50% 100%, rgba(229, 118, 151, 0.08), transparent 45%)",
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-8px)" },
        },
        "fade-up": {
          "0%": { opacity: "0", transform: "translateY(10px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        float: "float 5s ease-in-out infinite",
        "fade-up": "fade-up 0.7s cubic-bezier(0.2, 0.65, 0.3, 1) both",
      },
    },
  },
  plugins: [],
};

export default config;
