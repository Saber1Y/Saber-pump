"use client";
import React, { useState, useEffect } from "react";
import { formatEther } from "ethers";
import { useWriteContract, useReadContract, useAccount } from "wagmi";
import { isAddress } from "viem";

type FormProps = {
  ContractAddress: `0x${string}`;
  abi: any;
};

const Form: React.FC<FormProps> = ({ ContractAddress, abi }) => {
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState("");
  const [symbol, setSymbol] = useState("");
  const [description, setDescription] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [uploadURL, setUploadURL] = useState("");
  const [showMore, setShowMore] = useState(false);
  const [telegram, setTelegram] = useState("");
  const [website, setWebsite] = useState("");
  // const [creator, setCreator] = useState("");
  const [submittedData, setSubmittedData] = useState<any[]>([]);

  const { isConnected } = useAccount();

  const clearForm = () => {
    setName("");
    setSymbol("");
    setDescription("");
    setFile(null);
    setUploadURL("");
    setShowMore(false);
    setTelegram("");
    setWebsite("");
  };

  // const { data: creator } = useReadContract({
  //   address:ContractAddress,
  //   abi: abi,
  //   functionName: "getTokenCreator",
  //   // args: [index],
  // });

  // const { data: cost } = useReadContract({
  //   address: ContractAddress,
  //   abi: abi,
  //   functionName: "getCostPrice",
  // });



  const { writeContractAsync: createToken } = useWriteContract();
  const { writeContract, isPending, isSuccess, error } = useWriteContract();

  useEffect(() => {
    const storedData = sessionStorage.getItem("submittedData");
    if (storedData) {
      setSubmittedData(JSON.parse(storedData));
    }
  }, []);

  const handleFileChange = async (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) return;

    setFile(selectedFile);
    await handleUpload(selectedFile);
  };

  // Uploads the file to Pinata
  const handleUpload = async (selectedFile: File) => {
    const formData = new FormData();
    formData.append("file", selectedFile);

    try {
      const response = await fetch(
        "https://api.pinata.cloud/pinning/pinFileToIPFS",
        {
          method: "POST",
          headers: {
            Authorization: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiJiNTg4ZWFhNi0yNTUxLTQ0MGUtYmVmMy0yMmU4YTQ3YjQ0OTUiLCJlbWFpbCI6ImF5b2Rlamlha2ludG9iaTFAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsInBpbl9wb2xpY3kiOnsicmVnaW9ucyI6W3siZGVzaXJlZFJlcGxpY2F0aW9uQ291bnQiOjEsImlkIjoiRlJBMSJ9LHsiZGVzaXJlZFJlcGxpY2F0aW9uQ291bnQiOjEsImlkIjoiTllDMSJ9XSwidmVyc2lvbiI6MX0sIm1mYV9lbmFibGVkIjpmYWxzZSwic3RhdHVzIjoiQUNUSVZFIn0sImF1dGhlbnRpY2F0aW9uVHlwZSI6InNjb3BlZEtleSIsInNjb3BlZEtleUtleSI6ImVmZjQ0ZTM3NTczMDUwNzMzYzZhIiwic2NvcGVkS2V5U2VjcmV0IjoiOGNiNjdhNjdjMTUwMzdmN2M2ZTg`,
          },
          body: formData,
        }
      );

      const result = await response.json();
      const ipfsUrl = `https://gateway.pinata.cloud/ipfs/${result.IpfsHash}`;
      console.log("IPFS URL:", ipfsUrl);
      setUploadURL(ipfsUrl);
    } catch (error) {
      console.error("Error uploading file:", error);
    }
  };

  // Handles form submission
  const handleCreateToken = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    if (!isConnected) {
      alert("Please connect your wallet first."); // Show alert if wallet is not connected
      return;
    }

    if (!isAddress(ContractAddress)) {
      console.error("Invalid Ethereum address");
      return;
    }

    try {
      await createToken({
        address: ContractAddress,
        abi: abi,
        functionName: "createToken",
        args: [name, symbol, description, uploadURL], // Include image URL
      });
      console.log("Token created successfully!");
    } catch (error) {
      console.error("Error creating token:", error);
    }

    const newToken = {
      name,
      symbol,
      description,
      image: uploadURL, // Store uploaded image
      telegram: telegram || null,
      website: website || null,
    };

    const updatedData = [...submittedData, newToken];
    setSubmittedData(updatedData);
    sessionStorage.setItem("submittedData", JSON.stringify(updatedData));

    setName("");
    setSymbol("");
    setDescription("");
    setTelegram("");
    setWebsite("");
    setUploadURL("");
  };

  const handleCloseSale = async () => {
    try {
      writeContract({
        address: ContractAddress,
        abi,
        functionName: "closeSale",
        args: [ContractAddress],
      });
      console.log("fetching close sale");
    } catch (err) {
      console.error("Close sale failed:", err);
    }
  };

  return (
    <div className="text-center">
      <button
        className="text-[25px] font-semibold"
        onClick={() => {
          if (!isConnected) {
            alert("Please connect your wallet first.");
          } else {
            setShowForm(true);
          }
        }}
      >
        [ Create a Token ]
  
        {/* <p>Token Creator: {creator}</p> */}
      </button>

      {showForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-gray-900 bg-opacity-50">
          <div className="bg-white rounded-lg shadow-lg max-w-md w-full mx-auto p-6 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b">
              <h2 className="text-xl text-black font-semibold">Create Token</h2>
              <button
                onClick={() => {
                  setShowForm(false);
                  clearForm();
                }}
                className="text-gray-500 hover:bg-gray-200 rounded-full p-2"
              >
                <svg
                  className="w-5 h-5"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <form
              onSubmit={handleCreateToken}
              className="flex flex-col space-y-4 text-black"
            >
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Name"
                required
                className="border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <input
                type="text"
                value={symbol}
                onChange={(e) => setSymbol(e.target.value)}
                placeholder="Ticker"
                required
                className="border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <textarea
                placeholder="Description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                required
                className="w-full px-3 py-2 border rounded-md"
              />

              <div>
                <input
                  type="file"
                  accept="image/*"
                  onChange={handleFileChange}
                />
                {uploadURL && (
                  <div className="mt-2">
                    <img
                      src={uploadURL}
                      alt="Uploaded Preview"
                      className="w-full h-32 object-cover rounded-md"
                    />
                  </div>
                )}
              </div>

              <button
                type="button"
                onClick={() => setShowMore(!showMore)}
                className="bg-gray-200 text-gray-700 rounded-lg px-4 py-2 hover:bg-gray-300"
              >
                {showMore ? "Show Less" : "Show More"}
              </button>

              {showMore && (
                <div className="space-y-4">
                  <input
                    type="text"
                    value={telegram}
                    onChange={(e) => setTelegram(e.target.value)}
                    placeholder="Telegram Link (optional)"
                    className="border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <input
                    type="url"
                    value={website}
                    onChange={(e) => setWebsite(e.target.value)}
                    placeholder="Website (optional)"
                    className="border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              )}

              <button
                type="submit"
                className="bg-blue-600 text-white rounded-lg px-4 py-2 hover:bg-blue-700"
              >
                Create Token
              </button>
            </form>
          </div>
        </div>
      )}

      {submittedData.length > 0 && (
        <div className="mt-6 p-4 grid grid-cols-1 md:grid-cols-3 items-center place-items-center space-x-3 space-y-3 my-5 md:space-y-5">
          {submittedData.map((token, index) => (
            <div
              key={index}
              className="p-4 flex flex-col border rounded-lg shadow-sm text-left"
            >
              <div className="flex items-center justify-between pb-3 border-b">
                <p className="text-2xl  uppercase font-semibold">
                  {token.name}
                </p>
                <button
                  onClick={handleCloseSale}
                  disabled={isPending}
                  className="text-gray-500 hover:bg-gray-200 rounded-full p-2"
                >
                  {isPending ? (
                    "Closing..."
                  ) : (
                    <svg
                      className="w-5 h-5"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  )}
                </button>
              </div>
              <p className="text-lg font-bold leading-3 py-4">
                <strong>Symbol:</strong> {token.symbol}
              </p>
              <p className="text-lg font-bold leading-6 py-3">
                <strong>Description:</strong> {token.description}
              </p>
              <p>Creator </p>
              {token.image && (
                <img
                  src={token.image}
                  alt="Token Preview"
                  className="w-full h-32 object-cover rounded-md"
                />
              )}
              {token.telegram && (
                <p>
                  <strong>Telegram: </strong> {token.telegram}
                </p>
              )}
              {token.website && (
                <p>
                  <strong>Website: </strong> {token.website}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default Form;
