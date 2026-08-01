import { createElement, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { gsap } from 'gsap';
import './TextType.css';

const TextType = ({
  text,
  as: Component = 'div',
  typingSpeed = 50,
  initialDelay = 0,
  pauseDuration = 2000,
  deletingSpeed = 30,
  loop = true,
  className = '',
  showCursor = true,
  hideCursorWhileTyping = false,
  cursorCharacter = '|',
  cursorClassName = '',
  cursorBlinkDuration = 0.5,
  textColors = [],
  variableSpeed = undefined,
  onSentenceComplete = undefined,
  startOnVisible = false,
  reverseMode = false,
  ...props
}) => {
  const textArray = useMemo(() => (Array.isArray(text) ? text : [text]), [text]);
  const [displayedText, setDisplayedText] = useState('');
  const [currentCharIndex, setCurrentCharIndex] = useState(0);
  const [isDeleting, setIsDeleting] = useState(false);
  const [currentTextIndex, setCurrentTextIndex] = useState(0);
  const [isVisible, setIsVisible] = useState(!startOnVisible);
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);
  const cursorRef = useRef(null);
  const containerRef = useRef(null);

  const getRandomSpeed = useCallback(() => {
    if (!variableSpeed) return typingSpeed;
    const { min, max } = variableSpeed;
    return Math.random() * (max - min) + min;
  }, [variableSpeed, typingSpeed]);

  const getCurrentTextColor = () => {
    if (textColors.length === 0) return 'inherit';
    return textColors[currentTextIndex % textColors.length];
  };

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    const updatePreference = () => setPrefersReducedMotion(mediaQuery.matches);

    updatePreference();
    mediaQuery.addEventListener?.('change', updatePreference);
    return () => mediaQuery.removeEventListener?.('change', updatePreference);
  }, []);

  useEffect(() => {
    setDisplayedText('');
    setCurrentCharIndex(0);
    setIsDeleting(false);
    setCurrentTextIndex(0);
    setIsVisible(!startOnVisible);
  }, [textArray, startOnVisible]);

  useEffect(() => {
    if (!startOnVisible || !containerRef.current) return undefined;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) setIsVisible(true);
        });
      },
      { threshold: 0.1 },
    );

    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, [startOnVisible]);

  useEffect(() => {
    if (!showCursor || !cursorRef.current || prefersReducedMotion) return undefined;

    gsap.set(cursorRef.current, { opacity: 1 });
    const tween = gsap.to(cursorRef.current, {
      opacity: 0,
      duration: cursorBlinkDuration,
      repeat: -1,
      yoyo: true,
      ease: 'power2.inOut',
    });

    return () => tween.kill();
  }, [showCursor, cursorBlinkDuration, prefersReducedMotion]);

  useEffect(() => {
    if (!isVisible) return undefined;

    const currentText = textArray[currentTextIndex] ?? '';
    const processedText = reverseMode ? currentText.split('').reverse().join('') : currentText;

    if (prefersReducedMotion) {
      setDisplayedText(processedText);
      setCurrentCharIndex(processedText.length);
      setIsDeleting(false);
      return undefined;
    }

    let timeout;

    const executeTypingAnimation = () => {
      if (isDeleting) {
        if (displayedText === '') {
          setIsDeleting(false);
          if (currentTextIndex === textArray.length - 1 && !loop) return;

          onSentenceComplete?.(textArray[currentTextIndex], currentTextIndex);
          setCurrentTextIndex((previous) => (previous + 1) % textArray.length);
          setCurrentCharIndex(0);
        } else {
          timeout = window.setTimeout(() => {
            setDisplayedText((previous) => previous.slice(0, -1));
          }, deletingSpeed);
        }
      } else if (currentCharIndex < processedText.length) {
        timeout = window.setTimeout(
          () => {
            setDisplayedText((previous) => previous + processedText[currentCharIndex]);
            setCurrentCharIndex((previous) => previous + 1);
          },
          variableSpeed ? getRandomSpeed() : typingSpeed,
        );
      } else {
        onSentenceComplete?.(textArray[currentTextIndex], currentTextIndex);
        if (!loop && currentTextIndex === textArray.length - 1) return;
        timeout = window.setTimeout(() => setIsDeleting(true), pauseDuration);
      }
    };

    timeout = window.setTimeout(
      executeTypingAnimation,
      currentCharIndex === 0 && !isDeleting && displayedText === '' ? initialDelay : 0,
    );

    return () => window.clearTimeout(timeout);
  }, [
    currentCharIndex,
    currentTextIndex,
    deletingSpeed,
    displayedText,
    getRandomSpeed,
    initialDelay,
    isDeleting,
    isVisible,
    loop,
    onSentenceComplete,
    pauseDuration,
    prefersReducedMotion,
    reverseMode,
    textArray,
    typingSpeed,
    variableSpeed,
  ]);

  const currentText = textArray[currentTextIndex] ?? '';
  const shouldHideCursor =
    hideCursorWhileTyping && (currentCharIndex < currentText.length || isDeleting);

  return createElement(
    Component,
    {
      ref: containerRef,
      className: `text-type ${className}`.trim(),
      ...props,
    },
    <span className="text-type__content" style={{ color: getCurrentTextColor() }}>
      {displayedText}
    </span>,
    showCursor && !prefersReducedMotion && (
      <span
        ref={cursorRef}
        aria-hidden="true"
        className={`text-type__cursor ${cursorClassName} ${
          shouldHideCursor ? 'text-type__cursor--hidden' : ''
        }`.trim()}
      >
        {cursorCharacter}
      </span>
    ),
  );
};

export default TextType;
