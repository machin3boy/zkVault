"use client";
import React, { useEffect } from "react";
import { EvervaultCard } from "./components/ui/evervault-card";
import { LampDemo } from "./components/ui/lamp";
import { GoogleGeminiEffectDemo } from "./components/gemini";
import { Logo } from "./components/logo";
import { useMotionValue } from "framer-motion";

function App() {
  // Create motion values individually
  const pathLength1 = useMotionValue(0);
  const pathLength2 = useMotionValue(0);
  const pathLength3 = useMotionValue(0);
  const pathLength4 = useMotionValue(0);
  const pathLength5 = useMotionValue(0);

  const pathLengths = [
    pathLength1,
    pathLength2,
    pathLength3,
    pathLength4,
    pathLength5,
  ];

  useEffect(() => {
    const handleScroll = () => {
      const scrollTop = window.scrollY || document.documentElement.scrollTop;
      pathLengths.forEach((motionValue) => {
        const incrementFactor = 0.1; // Adjust the increment factor as needed
        motionValue.set(scrollTop * incrementFactor);
      });
    };

    window.addEventListener("scroll", handleScroll);

    return () => {
      window.removeEventListener("scroll", handleScroll);
    };
  }, [pathLengths]); // Include pathLengths in the dependency array

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-black bg-dot-white/[0.3] z-10">
      <div className="fixed top-0 left-0 w-full z-50 flex items-center justify-between px-2 py-2">
        <div className="flex items-center">
          <Logo className="h-10" />
          <div className="ml-2 font-bold text-2xl">zkVault</div>
        </div>
        <button className="bg-slate-800 no-underline group cursor-pointer relative shadow-2xl shadow-zinc-900 rounded-full p-px leading-6 font-bold text-white text-lg inline-block mr-2">
          <span className="absolute inset-0 overflow-hidden rounded-full">
            <span className="absolute inset-0 rounded-full bg-[image:radial-gradient(75%_100%_at_50%_0%,rgba(56,189,248,0.6)_0%,rgba(56,189,248,0)_75%)] opacity-0 transition-opacity duration-500 group-hover:opacity-100" />
          </span>
          <div className="relative flex space-x-2 items-center z-10 rounded-full bg-zinc-950 py-1 px-6 ring-1 ring-white/10 bg-sky-800/30">
            <span>Connect Wallet</span>
            <svg
              fill="none"
              height="16"
              viewBox="0 0 24 24"
              width="16"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M10.75 8.75L14.25 12L10.75 15.25"
                stroke="currentColor"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="1.5"
              />
            </svg>
          </div>
          <span className="absolute -bottom-0 left-[1.125rem] h-px w-[calc(100%-2.25rem)] bg-gradient-to-r from-emerald-400/0 via-emerald-400/90 to-emerald-400/0 transition-opacity duration-500 group-hover:opacity-40" />
        </button>
      </div>
      <LampDemo />
      <GoogleGeminiEffectDemo />
      <div className="mt-36 text-center font-semibold tracking-tight text-white text-4xl">
        Store Assets in <span className="text-sky-500">zkVault</span> With
        Bank-Level Security Using Custom MFA.
      </div>
      <div className="text-center font-semibold tracking-tight text-white text-4xl">
        Mint Mirrored Assets for Staking, DeFi, and Trading.
      </div>
      <div className="flex justify-center my-36">
        <EvervaultCard text="ETH" className="w-64 h-64 mx-10" />
        <EvervaultCard text="BTT" className="w-64 h-64 mx-10" />
        <EvervaultCard text="TRX" className="w-64 h-64 mx-10" />
      </div>
      <div className="text-center font-semibold tracking-tight text-white text-4xl">
        Leverage{" "}
        <span className="text-sky-500">
          Next-Generation Custom Security Logic
        </span>{" "}
        in Your Smart
      </div>
      <div className="text-center font-semibold tracking-tight text-white text-4xl mb-36">
        Contracts Seamlessly.
      </div>
    </div>
  );
}

export default App;